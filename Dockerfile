ARG BASE_IMAGE=opensuse/tumbleweed:latest
FROM ${BASE_IMAGE} AS builder

RUN zypper -vv ref
RUN     zypper dup -y
RUN     zypper install -y  cargo rust \
        gcc \
        clang lld \
        make automake autoconf \
        libopenssl-devel pam-devel \
        sqlite3-devel \
        sccache git
RUN     zypper clean -a

RUN git clone https://kanidm/kanidm /usr/src/kanidm

#COPY ${GITHUB_WORKSPACE}/kanidm /usr/src/kanidm
WORKDIR /usr/src/kanidm/kanidmd

ARG SCCACHE_REDIS
ARG KANIDM_FEATURES
ARG KANIDM_BUILD_PROFILE

RUN mkdir /scratch
RUN ln -s -f /usr/bin/clang /usr/bin/cc
RUN 	ln -s -f /usr/bin/ld.lld /usr/bin/ld
RUN 	if [ "${SCCACHE_REDIS}" != "" ]; \
		then \
			export CC="/usr/bin/sccache /usr/bin/clang"
RUN 			export RUSTC_WRAPPER=sccache
RUN 			sccache --start-server; \
		else \
			export CC="/usr/bin/clang"; \
	fi
RUN 	export RUSTC_BOOTSTRAP=1
RUN 	echo $KANIDM_BUILD_PROFILE
RUN 	echo $KANIDM_FEATURES
RUN 	CARGO_HOME=/scratch/.cargo cargo build \
		--features=${KANIDM_FEATURES} \
		--target-dir=/usr/src/kanidm/target/ \
		--release
RUN 	ls -al /usr/src/kanidm/target/release/
RUN 	if [ "${SCCACHE_REDIS}" != "" ]; \
		then sccache -s; \
	fi;

FROM ${BASE_IMAGE}

RUN zypper ref
RUN     zypper dup -y
RUN     zypper install -y timezone sqlite3 pam
RUN     zypper clean -a

COPY --from=builder /usr/src/kanidm/target/release/kanidmd /sbin/
COPY --from=builder /usr/src/kanidm/kanidmd_web_ui/pkg /pkg

EXPOSE 8443 3636
VOLUME /data

ENV RUST_BACKTRACE 1
CMD ["/sbin/kanidmd", "server", "-c", "/data/server.toml"]

