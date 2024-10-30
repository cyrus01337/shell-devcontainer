FROM debian:bookworm-slim AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
USER root

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --no-install-suggests ca-certificates curl git sudo zsh \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    \
    && addgroup $GROUP \
    && useradd -mg $USER -G sudo -s /usr/bin/fish $USER \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers;

FROM system AS configuration
USER $USER
WORKDIR /configuration

RUN git clone --depth=1 --separate-git-dir=$(mktemp -u) https://github.com/cyrus01337/shell-configuration.git . \
    && git submodule update --init --recursive;

FROM system AS github-cli
USER root

COPY ./install-github-cli.sh .

RUN ./install-github-cli.sh \
    && rm ./install-github-cli.sh;

FROM system AS starship
USER root

RUN sh -c "$(curl -sS https://starship.rs/install.sh)" -- -y;

FROM system AS final
USER $USER
WORKDIR $HOME

COPY --from=configuration --chown=$USER:$GROUP /configuration $HOME/.config/zsh
COPY --from=github-cli /etc/apt/keyrings/githubcli-archive-keyring.gpg /etc/apt/keyrings/
COPY --from=github-cli /etc/apt/sources.list.d/github-cli.list /etc/apt/sources.list.d/
COPY --from=github-cli /usr/bin/gh /usr/bin/gh
COPY --from=github-cli /usr/share/zsh/site-functions/_gh /usr/share/zsh/site-functions/_gh
COPY --from=github-cli /var/lib/dpkg/info/gh.* /var/lib/dpkg/info/
COPY --from=starship /usr/local/bin/starship /usr/local/bin/starship

RUN ln -s "$HOME/.config/zsh/.zshenv" \
    && sudo chown -R $USER:$GROUP $HOME/.config;

ENTRYPOINT ["zsh"]

