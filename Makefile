version_nginx=1.2.0
version_lua_module=0.7.15
version_dev_kit=0.2.18
version_lua_jit=2.0.0
version_echo_module=0.42
version_eval_module=2011.01.27
version_set_misc=0.22rc8
version_pcre=8.10

default: configure build

set_version:
	@mkdir -p versions current
	@if [ ! -d versions/nginx-${version_nginx} ]; then cd versions; [ ! -f nginx-${version_nginx}.tar.gz ] && wget -c -N http://nginx.org/download/nginx-${version_nginx}.tar.gz; tar xzf nginx-${version_nginx}.tar.gz; cd ..; fi
	@mkdir -p versions/nginx-${version_nginx}/objs
	@for i in docs auto conf configure contrib src Makefile objs; do cd current && ln -fs ../versions/nginx-${version_nginx}/$$i && cd ..; done
	@make ensure_custom_makefile
	@echo "Using nginx ${version_nginx} version"

ensure_custom_makefile:
	@if [ ! -f current/CustomMakefile ]; then touch current/CustomMakefile && \
	echo "default:	build\n\nclean:\n\tfind objs -type f -name *.o -delete\n" >> current/CustomMakefile && \
	echo "clean-module:\n\trm -f objs/addon/src/ngx_http_redis2*.o\n\nbuild: clean-module\n\t@make -f objs/Makefile\n" >> current/CustomMakefile; \
	else exit 0; fi  

extra_modules:
	@lua_nginx_module_url="https://github.com/chaoslawful/lua-nginx-module/archive/v"; \
	ngx_devel_kit_url="https://github.com/simpl/ngx_devel_kit/archive/v"; \
	echo_nginx_module_url="https://github.com/agentzh/echo-nginx-module/archive/v"; \
	nginx_eval_module_url="https://github.com/agentzh/nginx-eval-module/archive/"; \
	set_misc_nginx_module_url="https://github.com/agentzh/set-misc-nginx-module/archive/v"; \
	pcre_url="http://downloads.sourceforge.net/pcre/pcre-"; \
	for module in pcre:${version_pcre} set_misc_nginx_module:${version_set_misc} nginx_eval_module:${version_eval_module} lua_nginx_module:${version_lua_module} ngx_devel_kit:${version_dev_kit} echo_nginx_module:${version_echo_module}; do \
		module_url=$${module%%:*}_url; \
		if [ ! -d versions/$${module/:/-} ]; then cd versions; [ ! -f $${module/:/-}.tar.gz ] && wget -c -N $${!module_url}$${module#*:}.tar.gz -O $${module/:/-}.tar.gz ; tar xzf $${module/:/-}.tar.gz; cd ..; fi; \
	done
	@if [ ! -d versions/LuaJIT-${version_lua_jit} ]; then cd versions; [ ! -f LuaJIT-${version_lua_jit}.tar.gz ] && wget -c -N http://luajit.org/download/LuaJIT-${version_lua_jit}.tar.gz; tar xzf LuaJIT-${version_lua_jit}.tar.gz; fi;
	@cd versions/LuaJIT-${version_lua_jit} && sed -i -e "s#^export PREFIX=.*\$$#export PREFIX= $$(pwd)#" Makefile && make && make install && cd .. 
	@cd versions/pcre-${version_pcre} && ./configure && make

modules := --add-module=../ \
	--add-module=../versions/ngx_devel_kit-${version_dev_kit} \
	--add-module=../versions/lua-nginx-module-${version_lua_module} \
	--add-module=../versions/echo-nginx-module-${version_echo_module} \
	--add-module=../versions/nginx-eval-module-${version_eval_module} \
	--add-module=../versions/set-misc-nginx-module-${version_set_misc} \
	--with-pcre=../versions/pcre-${version_pcre}

build: set_version ensure_custom_makefile
	cd current && make -f CustomMakefile build

clean: set_version ensure_custom_makefile
	cd current && make -f CustomMakefile clean

clean-module: set_version ensure_custom_makefile
	cd current && make -f CustomMakefile clean-module

configure: set_version extra_modules
	cd current && LUAJIT_LIB=../versions/LuaJIT-${version_lua_jit}/lib LUAJIT_INC=../versions/LuaJIT-${version_lua_jit}/include/luajit-2.0  \
	./configure \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	${modules}

config_debug:
	cd current && ./configure \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-debug \
	${modules}

test: clean-module build
	@PATH=$$PATH:./current/objs prove -r t
