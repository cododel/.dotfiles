
import http from 'http';

export class HttpServer {
  constructor(port, state) {
    this.port = port;
    this.state = state;
  }

  start() {
    this.httpServer = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(this.state.lastMessage + '\n');
    }).listen(this.port);
  }

  stop() {
    this.httpServer.close();
  }
}