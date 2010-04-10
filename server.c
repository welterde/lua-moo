#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/socket.h>
#include <netdb.h>

int server(lua_State *L) {
	struct addrinfo hints, *res;
	int sockfd, clientfd;
	socklen_t addr_size;
	struct sockaddr_storage their_addr;
	char buffer[1024];

	int true = 1;

	memset(&hints, 0, sizeof hints);
	hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

	getaddrinfo(NULL, "7777", &hints, &res);

	sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &true, sizeof true);
	bind(sockfd, res->ai_addr, res->ai_addrlen);
	listen(sockfd, 10);

	while (1) {
		size_t bytes = 0;
		addr_size = sizeof their_addr;
		clientfd = accept(sockfd, (struct sockaddr *)&their_addr, &addr_size);

		printf("[C:New connection]\n");

		while ((bytes = recv(clientfd, buffer, 1024, 0)) > 0) {
			buffer[bytes - 2] = 0;
			printf("[C:server]::%s\n", buffer);

			// Pass the input off to Lua
			lua_getglobal(L, "wizard");
			lua_pushstring(L, "input");
			lua_gettable(L, -2);
			lua_getglobal(L, "wizard"); // self
			lua_pushlstring(L, buffer, bytes-2);
			
			// 2 arg, 0 result
			if (lua_pcall(L, 2, 0, 0) != 0) {
				error(L, "error running function `f': %s", 
					  lua_tostring(L, -1));
			}
		}

		printf("[C:Disconnect]\n");

		close(clientfd);
	}
}

int main (void) {
	int error;
	lua_State *L = lua_open();
	luaL_openlibs(L);

	error = luaL_loadfile(L, "core.lua") || lua_pcall(L, 0, 0, 0);
	if (error) {
		fprintf(stderr, "%s", lua_tostring(L, -1));
		lua_pop(L, 1);  /* pop error message from the stack */
	}

	server(L);

	lua_close(L);
}
