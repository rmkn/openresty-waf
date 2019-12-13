FROM rmkn/centos7
LABEL maintainer "rmkn"

ENV OPENRESTY_VERSION 1.15.8.2
ENV OPENSSL_VERSION 1.1.1d
ENV PCRE_VERSION 8.43
ENV ZLIB_VERSION 1.2.11
ENV MODSECURITY_NGINX_VERSION 1.0.0
ENV OWASP_CRS_VERSION 3.1.0
ENV LUAROCKS_VERSION 3.2.1

RUN yum install -y perl make gcc gcc-c++ pcre-devel ccache systemtap-sdt-devel patch git libtool autoconf file flex bison yajl yajl-devel curl-devel curl GeoIP-devel doxygen unzip

RUN curl -o /usr/local/src/zlib.tar.gz -SL https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/zlib.tar.gz -C /usr/local/src \
	&& cd /usr/local/src/zlib-${ZLIB_VERSION} \
	&& ./configure --prefix=/usr/local/openresty/zlib \
	&& make CFLAGS='-O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -g' SFLAGS='-O3 -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -g' \
	&& make install

RUN curl -o /usr/local/src/openssl.tar.gz -SL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/openssl.tar.gz -C /usr/local/src \
	&& cd /usr/local/src/openssl-${OPENSSL_VERSION} \
	&& curl -o sess_set_get_cb_yield.patch -SL https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.1c-sess_set_get_cb_yield.patch \
	&& patch -p1 < sess_set_get_cb_yield.patch \
	&& ./config no-threads shared zlib -g enable-ssl3 enable-ssl3-method --prefix=/usr/local/openresty/openssl --libdir=lib -I/usr/local/openresty/zlib/include -L/usr/local/openresty/zlib/lib -Wl,-rpath,/usr/local/openresty/zlib/lib:/usr/local/openresty/openssl/lib \
	&& make CC='ccache gcc -fdiagnostics-color=always' \
	&& make install_sw

RUN curl -o /usr/local/src/pcre.tar.gz -SL https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/pcre.tar.gz -C /usr/local/src \
	&& cd /usr/local/src/pcre-${PCRE_VERSION} \
	&& ./configure --prefix=/usr/local/openresty/pcre --libdir=/usr/local/openresty/pcre/lib --disable-cpp --enable-jit --enable-utf --enable-unicode-properties \
	&& make CC='ccache gcc -fdiagnostics-color=always' V=1 \
	&& make install

RUN cd /usr/local/src \
	&& git clone https://github.com/SpiderLabs/ModSecurity \
	&& cd /usr/local/src/ModSecurity \
	&& ./build.sh \
	&& git submodule init \
	&& git submodule update \
	&& ./configure  \
	&& make \
	&& make install

RUN curl -o /usr/local/src/modsecurity-nginx.tar.gz -SL https://github.com/SpiderLabs/ModSecurity-nginx/archive/v${MODSECURITY_NGINX_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/modsecurity-nginx.tar.gz -C /usr/local/src

RUN curl -o /usr/local/src/openresty.tar.gz -SL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/openresty.tar.gz -C /usr/local/src \
	&& cd /usr/local/src/openresty-${OPENRESTY_VERSION} \
	&& ./configure \
		--prefix="/usr/local/openresty" \
		--with-cc='ccache gcc -fdiagnostics-color=always' \
		--with-cc-opt="-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/zlib/include -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include" \
		--with-ld-opt="-L/usr/local/openresty/zlib/lib -L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/zlib/lib:/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib" \
		--with-pcre-jit \
		--without-http_rds_json_module \
		--without-http_rds_csv_module \
		--without-lua_rds_parser \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-http_v2_module \
		--without-mail_pop3_module \
		--without-mail_imap_module \
		--without-mail_smtp_module \
		--with-http_stub_status_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_auth_request_module \
		--with-http_secure_link_module \
		--with-http_random_index_module \
		--with-http_gzip_static_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-threads \
		--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' \
		--with-dtrace-probes \
		--add-dynamic-module=../ModSecurity-nginx-${MODSECURITY_NGINX_VERSION} \
	&& gmake \
	&& gmake install

RUN ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/bin/openresty

RUN curl -o /usr/local/src/owasp-modsecurity-crs.tar.gz -SL https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v${OWASP_CRS_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/owasp-modsecurity-crs.tar.gz -C /usr/local \
	&& cd /usr/local \
	&& ln -sf owasp-modsecurity-crs-${OWASP_CRS_VERSION} owasp-modsecurity-crs \
	&& mv /usr/local/owasp-modsecurity-crs/crs-setup.conf.example /usr/local/owasp-modsecurity-crs/crs-setup.conf

RUN curl -o /usr/local/src/luarocks.tar.gz -SL https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz \
	&& tar zxf /usr/local/src/luarocks.tar.gz  -C /usr/local/src \
	&& cd /usr/local/src/luarocks-${LUAROCKS_VERSION} \
	&& ./configure --with-lua=/usr/local/openresty/luajit/ \
	&& make \
	&& make install

RUN rm -rf /usr/local/openresty/zlib/share \
	&& rm -f  /usr/local/openresty/zlib/lib/*.la \
	&& rm -rf /usr/local/openresty/zlib/lib/pkgconfig \
	&& rm -f  /usr/local/openresty/zlib/lib/*.a \
	&& rm -rf /usr/local/openresty/zlib/include \
	&& rm -rf /usr/local/openresty/openssl/bin/c_rehash \
	&& rm -rf /usr/local/openresty/openssl/lib/pkgconfig \
	&& rm -rf /usr/local/openresty/openssl/misc \
	&& rm -f  /usr/local/openresty/openssl/lib/*.a \
	&& rm -rf /usr/local/openresty/openssl/include \
	&& rm -rf /usr/local/openresty/pcre/bin \
	&& rm -rf /usr/local/openresty/pcre/share \
	&& rm -f  /usr/local/openresty/pcre/lib/*.la \
	&& rm -f  /usr/local/openresty/pcre/lib/*pcrecpp* \
	&& rm -f  /usr/local/openresty/pcre/lib/*pcreposix* \
	&& rm -rf /usr/local/openresty/pcre/lib/pkgconfig \
	&& rm -f  /usr/local/openresty/pcre/lib/*.a \
	&& rm -rf /usr/local/openresty/pcre/include \
	&& rm -rf /usr/local/openresty/luajit/share/man \
	&& rm -rf /usr/local/openresty/luajit/lib/libluajit-5.1.a \
	&& rm -f  /usr/local/openresty/bin/resty \
	&& rm -f  /usr/local/openresty/bin/restydoc \
	&& rm -f  /usr/local/openresty/bin/restydoc-index \
	&& rm -f  /usr/local/openresty/bin/md2pod.pl \
	&& rm -f  /usr/local/openresty/bin/nginx-xml2pod \
	&& rm -f  /usr/local/openresty/resty.index \
	&& rm -rf /usr/local/openresty/pod \
	&& rm -rf /usr/local/openresty/bin/opm \
	&& rm -rf /usr/local/openresty/site/manifest \
	&& rm -rf /usr/local/openresty/site/pod \
	&& rm -rf /usr/local/src/zlib-${ZLIB_VERSION} \
	&& rm -rf /usr/local/src/openssl-${OPENSSL_VERSION} \
	&& rm -rf /usr/local/src/pcre-${PCRE_VERSION} \
	&& rm -rf /usr/local/src/openresty-${OPENRESTY_VERSION} \
	&& rm -f  /usr/local/src/zlib.tar.gz \
	&& rm -f  /usr/local/src/openssl.tar.gz \
	&& rm -f  /usr/local/src/pcre.tar.gz \
	&& rm -f  /usr/local/src/openresty.tar.gz

COPY nginx.conf /usr/local/openresty/nginx/conf/
COPY default.conf security.conf /usr/local/openresty/nginx/conf/conf.d/
COPY main.conf /usr/local/openresty/nginx/modsec/
COPY openssl.cnf /usr/local/openresty/openssl/ssl/
RUN cp /usr/local/src/ModSecurity/modsecurity.conf-recommended /usr/local/openresty/nginx/modsec/modsecurity.conf 
RUN cp /usr/local/src/ModSecurity/unicode.mapping /usr/local/openresty/nginx/modsec/

EXPOSE 80 443

CMD ["/usr/bin/openresty", "-g", "daemon off;"]

