FROM debian:bookworm-slim AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV PATH="$PATH:/usr/bin"
ENV DOTFILES_DIRECTORY="$HOME/.local/share/dotfiles"
ENV HELPFUL_PACKAGES="tmux"
ENV TRANSIENT_PACKAGES="jq"
USER root

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --no-install-suggests ca-certificates curl fish git stow sudo \
    $HELPFUL_PACKAGES \
    $TRANSIENT_PACKAGES \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    \
    && addgroup $GROUP \
    && useradd -mg $USER -G sudo -s /usr/bin/fish $USER \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers;

FROM system AS delta
USER root

RUN curl https://api.github.com/repos/dandavison/delta/releases/latest \
    | jq -r ".assets[9].browser_download_url" \
    | xargs -r -I{} curl -L "{}" -o delta.deb \
    && dpkg -i delta.deb \
    && rm delta.deb;

FROM system AS dotfiles
USER $USER
WORKDIR /dotfiles

RUN git clone --depth=1 https://github.com/cyrus01337/dotfiles-but-better.git . \
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
USER root

RUN apt-get remove -y jq \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*;

COPY --from=delta /usr/bin/delta /usr/bin/delta
COPY --from=delta /usr/share/doc/git-delta/ /usr/share/doc/git-delta/
COPY --from=delta /var/lib/dpkg/info/git-delta.* /var/lib/dpk/info/
COPY --from=dotfiles --chown=$USER:$GROUP /dotfiles $DOTFILES_DIRECTORY
COPY --from=github-cli /etc/apt/keyrings/githubcli-archive-keyring.gpg /etc/apt/keyrings/
COPY --from=github-cli /etc/apt/sources.list.d/github-cli.list /etc/apt/sources.list.d/
COPY --from=github-cli /usr/bin/gh /usr/bin/gh
COPY --from=github-cli /usr/share/zsh/site-functions/_gh /usr/share/zsh/site-functions/_gh
COPY --from=github-cli /var/lib/dpkg/info/gh.* /var/lib/dpkg/info/
COPY --from=starship /usr/local/bin/starship /usr/local/bin/starship

USER $USER
WORKDIR $DOTFILES_DIRECTORY

RUN stow --adopt . -t ~ \
    && git reset --hard \
    && stow . -t ~ \
    && sudo chown -R $USER:$GROUP $DOTFILES_DIRECTORY \
    && rm -rf $DOTFILES_DIRECTORY/.git;

WORKDIR $HOME

ENTRYPOINT ["fish"]

