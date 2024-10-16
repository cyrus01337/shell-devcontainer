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
    && useradd -mg $USER -G sudo -s /usr/bin/zsh $USER \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers;

FROM system AS configuration
USER $USER
WORKDIR /configuration

RUN git clone --depth=1 --separate-git-dir=$(mktemp -u) https://github.com/cyrus01337/shell-configuration.git . \
    && git submodule update --init --recursive;

FROM system AS starship
USER root

RUN sh -c "$(curl -sS https://starship.rs/install.sh)" -- -y;

FROM system AS final
USER $USER
WORKDIR $HOME

COPY --from=configuration --chown=$USER:$GROUP /configuration $HOME/.config/zsh
COPY --from=starship /usr/local/bin/starship /usr/local/bin/starship

RUN ln -s "$HOME/.config/zsh/.zshenv" \
    && sudo chown -R $USER:$GROUP $HOME/.config;

ENTRYPOINT ["zsh"]

