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

#include <pthread.h>
#define NUM_THREADS 10

struct thread_init{
	int clientfd;
	lua_State *L;	
};

#define WEBSOCKET_HANDSHAKE "HTTP/1.1 101 Web Socket Protocol Handshake\r\nUpgrade: WebSocket\r\nConnection: Upgrade\r\nWebSocket-Origin: http://192.168.1.2\r\nWebSocket-Location: ws://192.168.1.2:7777/luamoo\r\n\r\n"

char *websocket_handshake() {}

void *handle_client(void *thread) {
	char buffer[1024];
	size_t bytes = 0;
	struct thread_init *client = (struct thread_init *)thread;
	lua_State *L = client->L;
	int clientfd = client->clientfd;
	int cmd_count = 0;
	int websocket = 0;

	while ((bytes = recv(clientfd, buffer, 1024, 0)) > 0) {
		printf("[C:server]::%s\n", buffer);

		if (cmd_count == 0) {
			// Detect websocket clients
			if (strncmp("GET /luamoo HTTP/1.1", buffer, 20) == 0) {
				websocket = 1;
				printf("[C:server]::WebSocket client detected\n");
				if (strstr(buffer, "\r\n\r\n") == 0) {
					printf("[C:websocket]::%s\n", buffer);
				}
				send(clientfd, WEBSOCKET_HANDSHAKE, 
					 strlen(WEBSOCKET_HANDSHAKE), 0);
				cmd_count++;
				continue;
			}
		}

		if (!websocket && bytes >= 2) buffer[bytes - 2] = 0;

		// Pass the input off to Lua
		// Probably not safe at all with threading but who knows!
		lua_getglobal(L, "wizard");
		lua_pushstring(L, "input");
		lua_gettable(L, -2);
		lua_getglobal(L, "wizard"); // self
		if (websocket)
			lua_pushlstring(L, buffer+1, bytes-2);
		else
			lua_pushlstring(L, buffer, bytes-2);

		// 2 arg, 1 result
		if (lua_pcall(L, 2, 1, 0) != 0) {
			printf("[C:error running function `input':]\n\t%s\n", lua_tostring(L, -1));
			//error(L, "error running function `f': %s", 
			//lua_tostring(L, -1));
		}
		else {
			const char *result = lua_tostring(L, -1);
			if (!lua_isstring(L, -1))
				printf("[C:error function `input` must return a string\n");
			if (websocket) send(clientfd, "\0", 1, 0); // <
			send(clientfd, result, strlen(result), 0);
			if (websocket) send(clientfd, "\xFF", 1, 0); // >
		}
		cmd_count++;
	}
	printf("[C:Disconnect]\n");
	close(clientfd);
	pthread_exit(NULL);
}

int server(lua_State *L) {
	struct addrinfo hints, *res;
	int sockfd, clientfd;
	socklen_t addr_size;
	struct sockaddr_storage their_addr;

	struct thread_init clients[NUM_THREADS];
	pthread_t client_threads[NUM_THREADS];
	long t = 0;

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
		addr_size = sizeof their_addr;
		clientfd = accept(sockfd, (struct sockaddr *)&their_addr, &addr_size);

		printf("[C:New connection]\n");

		clients[t].clientfd = clientfd;
		clients[t].L = L;
		pthread_create(&client_threads[t], NULL, handle_client, (void *)&clients[t]);
		t++;
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

	pthread_exit(NULL);
}
