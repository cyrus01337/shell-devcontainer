FROM debian:bookworm-slim AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV DOTFILES_DIRECTORY="$HOME/.local/share/dotfiles"
ENV HELPFUL_PACKAGES="bat curl fd-find fzf git tmux wget"
ENV TRANSIENT_PACKAGES="apt-utils"
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    ca-certificates fish openssh-client sudo \
    $TRANSIENT_PACKAGES \
    && apt-get install -y $HELPFUL_PACKAGES \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*;
RUN addgroup $GROUP \
    && useradd -mg $USER -G sudo -s /usr/bin/fish $USER \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p $HOME/.ssh;
RUN ssh-keyscan github.com >> $HOME/.ssh/known_hosts;

FROM debian:bookworm-slim AS delta
USER root

RUN apt-get update \
    && apt-get install -y curl jq;
RUN curl https://api.github.com/repos/dandavison/delta/releases/latest \
    | jq -r ".assets[9].browser_download_url" \
    | xargs -r -I {} curl -L "{}" -o delta.deb \
    && dpkg -i delta.deb \
    && rm delta.deb \
    \
    && apt-get remove -y curl jq \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*;

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
WORKDIR /tmp

COPY ./install-docker.sh .

RUN ./install-docker.sh \
    && rm ./install-docker.sh;

FROM docker AS final
USER root

COPY --from=delta /usr/bin/delta /usr/bin/delta
COPY --from=github-cli /usr/bin/gh /usr/bin/gh
COPY --from=starship /usr/local/bin/starship /usr/local/bin/starship

RUN apt-get remove -y $TRANSIENT_PACKAGES \
    && apt-get autoremove -y;

USER $USER
WORKDIR $HOME

ENTRYPOINT ["sleep", "infinity"]
