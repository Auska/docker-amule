FROM alpine:latest
MAINTAINER docker@chabs.name

ENV CRYPTOPP_VERSION CRYPTOPP_8_2_0
ENV TZ Asia/Shanghai

# Add startup script
ADD amule.sh /home/amule/amule.sh

# Build
RUN apk --update add geoip libpng sudo zlib bash tzdata wxgtk \
    && apk --update add --virtual build-dependencies build-base git wget flex bison autoconf automake pkgconf libtool expat-dev zlib-dev gettext-dev wxgtk-dev asio-dev \
    && mkdir -p /opt \&& cd /opt \
    && git clone --branch ${CRYPTOPP_VERSION} --single-branch "https://github.com/weidai11/cryptopp" /opt/cryptopp \
    && cd /opt/cryptopp \
    && sed -i -e 's/^CXXFLAGS/#CXXFLAGS/' GNUmakefile \
    && export CXXFLAGS="${CXXFLAGS} -DNDEBUG -fPIC" \
    && make -f GNUmakefile \
    && install -Dm644 libcryptopp.a /usr/lib/ \
    && mkdir -p /usr/include/cryptopp \
    && install -m644 *.h /usr/include/cryptopp/ \
    && mkdir -p /opt/amule \
    && git clone --depth 1 https://github.com/persmule/amule-dlp.git /opt/amule \
    && cd /opt/amule \
    && ./autogen.sh \
    && ./configure \
        --disable-amule-gui \
        --disable-wxcas \
        --disable-alc \
        --disable-cas \
        --disable-alcc \
        --disable-nls \
        --prefix=/usr \
        --mandir=/usr/share/man \
        --enable-amule-daemon \
        --enable-amulecmd \
        --enable-webserver \
        --enable-geoip \
        --enable-mmap \
        --enable-optimize \
        --disable-upnp \
        --disable-debug \
        --with-boost \
    && make \
    && make install \
    && mkdir -p /opt/antiLeech \
    && git clone --depth 1 https://github.com/persmule/amule-dlp.antiLeech.git /opt/antiLeech \
    && cd /opt/antiLeech \
    && ./autogen.sh \
    && ./configure \
        --prefix=/usr \
    && make \
    && make install \
    && cd /usr/share/amule-dlp/webserver \
    && git clone --depth 1 https://github.com/MatteoRagni/AmuleWebUI-Reloaded \
    && rm -rf AmuleWebUI-Reloaded/.git AmuleWebUI-Reloaded/doc-images \
    && chmod a+x /home/amule/amule.sh \
    && rm -rf /usr/lib/libcryptopp.a /usr/include/cryptopp/ \
    && apk del build-dependencies \
    && rm -rf /var/cache/apk/* && rm -rf /opt

EXPOSE 4711/tcp 4672/udp 4662/tcp

ENTRYPOINT ["/home/amule/amule.sh"]