import tmi from 'tmi.js';

export class TwitchBot {


  constructor(state, token) {
    this.state = state;
    this.opts = {
      identity: {
        username: 'alx_n_smith',
        password: 'oauth:' + token
      },
      channels: [
        'alx_n_smith'
      ]
    };
  }

  run(opts = {}) {
    // Create a client with our options
    const client = new tmi.client(Object.assign(this.opts, opts));

    // Register our event handlers (defined below)
    client.on('message', this.onMessageHandler.bind(this));
    client.on('connected', this.onConnectedHandler);

    // Connect to Twitch:
    client.connect().catch(e => console.log(e));
  }

  // Called every time a message comes in
  onMessageHandler(target, context, msg, self) {
    if (self) { return; } // Ignore messages from the bot
    const message = context.username + ': ' + msg;
    this.state.lastMessage = message;
  }

  // Called every time the bot connects to Twitch chat
  onConnectedHandler(addr, port) {
    console.log(`* Connected to ${addr}:${port}`);
  }
}
