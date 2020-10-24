FROM alpine:latest
MAINTAINER docker@chabs.name

ENV WX_VERSION 3.0.5
ENV CRYPTOPP_VERSION CRYPTOPP_8_2_0
ENV TZ Asia/Shanghai

RUN apk --update add geoip libpng sudo zlib bash tzdata && \
    apk --update add --virtual build-dependencies build-base git wget expat-static zlib-static autoconf automake gettext-dev pkgconf wxgtk wxgtk-dev flex bison asio-dev libtool

# Add startup script
ADD amule.sh /home/amule/amule.sh
ADD 001_Record_IP.patch /001.patch

# Build
RUN mkdir -p /opt \&& cd /opt \
    && wget "https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2" \
    && tar xvfj wxWidgets-${WX_VERSION}.tar.bz2 \
    && cd wxWidgets-${WX_VERSION} \
    && ./configure \
        --enable-compat28 \
        --disable-debug \
        --enable-static \
        --disable-shared \
    && make \
    && make install \
    && cd /opt \
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
    && patch -p1 < /001.patch \
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
        --enable-boost-static \
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
    && cd /opt/wxWidgets-${WX_VERSION} \
    && make uninstall \
    && apk del build-dependencies \
    && rm -rf /var/cache/apk/* && rm -rf /opt && rm /001.patch

EXPOSE 4711/tcp 4712/tcp 4672/udp 4665/udp 4662/tcp 4661/tcp

ENTRYPOINT ["/home/amule/amule.sh"]