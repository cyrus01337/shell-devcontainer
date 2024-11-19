FROM debian:bookworm-slim AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV DOTFILES_DIRECTORY="$HOME/.local/share/dotfiles"
ENV HELPFUL_PACKAGES="openssh-client tmux"
ENV TRANSIENT_PACKAGES="stow"
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests nala \
    && nala install -y --no-install-recommends --no-install-suggests ca-certificates fish git sudo \
    $HELPFUL_PACKAGES \
    $TRANSIENT_PACKAGES \
    && nala autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    \
    && addgroup $GROUP \
    && useradd -mg $USER -G sudo -s /usr/bin/fish $USER \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers;

FROM debian:bookworm-slim AS delta
USER root

RUN apt-get update \
    && apt-get install -y curl jq;
RUN curl https://api.github.com/repos/dandavison/delta/releases/latest \
    | jq -r ".assets[9].browser_download_url" \
    | xargs -r -I{} curl -L "{}" -o delta.deb \
    && dpkg -i delta.deb \
    && rm delta.deb \
    && rm -rf /var/lib/apt/lists/*;

FROM system AS dotfiles
USER $USER
WORKDIR /dotfiles

RUN git clone --depth=1 https://github.com/cyrus01337/dotfiles-but-better.git . \
    && git submodule update --init --recursive;

FROM system AS github-cli
USER root

COPY ./install-github-cli.sh .

RUN ./install-github-cli.sh \
    && rm -rf ./install-github-cli.sh /var/lib/apt/lists/*;

FROM debian:bookworm-slim AS starship
USER root

RUN apt-get update \
    && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*;
RUN sh -c "$(curl -sS https://starship.rs/install.sh)" -- -y;

FROM system AS docker
USER root

RUN sh -c "$(curl -fsSL https://get.docker.com)";

FROM docker AS final
ENV DOTFILES_DIRECTORY="$HOME/.local/share/dotfiles"
USER root

COPY --from=delta /usr/bin/delta /usr/bin/delta
COPY --from=dotfiles --chown=$USER:$GROUP /dotfiles $DOTFILES_DIRECTORY
COPY --from=github-cli /usr/bin/gh /usr/bin/gh
COPY --from=starship /usr/local/bin/starship /usr/local/bin/starship

USER $USER
WORKDIR $DOTFILES_DIRECTORY

RUN stow --adopt . -t ~ \
    && git reset --hard \
    && stow . -t ~ \
    && rm -rf .git/;

USER root

RUN chown -R $USER:$GROUP $DOTFILES_DIRECTORY \
    && nala remove -y $TRANSIENT_PACKAGES \
    && nala autoremove -y;

USER $USER
WORKDIR $HOME

ENTRYPOINT ["sleep", "infinity"]
