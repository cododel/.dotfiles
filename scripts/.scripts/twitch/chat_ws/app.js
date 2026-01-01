import { TwitchBot } from "./bot.js";
import { HttpServer } from "./server.js";

const state = {
  _lastMessage: {
    value: "",
    ts: 0,
  },

  set lastMessage(msg) {
    this._lastMessage.value = msg;
    this._lastMessage.ts = Date.now();
  },

  get lastMessage() {
    let message = this._lastMessage.value;
    if (Date.now() - this._lastMessage.ts < 9000) message = "[NEW] " + message;
    return message;
  },
};

const bot = new TwitchBot(state, process.env.TOKEN);
bot.run();

const server = new HttpServer(3999, state);
server.start();
