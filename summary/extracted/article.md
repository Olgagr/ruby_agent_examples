# Connection avalanche safety tips and prepping for real-time applications

Launching a greenfield application or rolling out a new feature can be like going out into the wilderness: you can never quite be sure what is waiting for you out there (bears, falling rocks …or an avalanche?) With distributed systems, you can face many common problems, and a little awareness and preparedness could be what keeps your service alive! Today, I’d like to talk about one such problem: the **thundering herd problem**, as it relates to real-time applications. We’ll discuss how you can minimize risks by following some simple safety rules.

What is the thundering herd problem? The term has already been used in the world of software engineering for decades as a way to describe _scheduler thrashing_ problems in the Linux kernel—but this is too far beyond the scope of this post. Rather, we need to translate this problem to web applications, or distributed systems in general.

> A thundering herd incident is a sudden influx of the number of simultaneous requests which overwhelms server resources and causes significant system lags, crashes, and, thus, cascading failures.

This “sudden influx” can be caused by various reasons; the most common are:

- A recovery issue: if your service was unavailable for a while, you might expect a burst of traffic as availablity returns due to downstream services retrying all the requests that failed while the service was down.

- A celebrity issue: a superstar user posts an update or a link somewhere, and all their followers try to see it or click on it immediately, and boom, a few orders of magnitude more requests than typical, and in a short period of time. One such example is the “Hacker News Effect” (which we may or may not observe after publishing this post 😁).

There are also flavors of the thundering herd problem specific to different kinds of systems. For example, there is the _cache stampede_ problem; this is a situation where many clients concurrently request a resource missing in the distributed cache and cause high numbers of upstream requests.

In the world of real-time applications, we also have our specific version of the thundering herd problem: connection avalanches. Before digging deeper into this problem and its solutions, let’s recall what makes real-time applications special!

There are many types of real-time applications, from boring chats to ~~AI chats~~ collaborative editors. And what do all of them have in common from the technical point of view? They serve **persistent, long-lived, stateful clients**, and there is constant, usually bi-directional, communication between them and the server. Whenever a new client connects to the server, it must first initialize its state. The initialization process usually involves authentication, authorization, and subscribing to multiple data streams—quite a number of operations to be performed by the server. And we didn’t even count the underlying transport overhead (e.g., WebSockets over TLS over TCP).

> We can certainly say that real-time client initialization is a _resource-intensive operation_.

Imagine an online events platform (like [Vito](https://vi.to/), for example). Whenever a live event starts, every client sets up a connection to the real-time server to receive various updates as the event goes on. Upon connecting, the server must verify the client’s authenticity and access to the event; as this handshake succeeds, the client concurrently subscribes to different data streams: messaging, presence (a list of users), media events (play/pause, new media, and so on), and, probably, a few more (e.g., analytics). So, it’s easy to see half a dozen actions being processed by the server for each client.

Now, imagine you have a very popular event on the platform with multiple thousand attendees. It’s up and going and everything seems fine. But then, a pull request with some patch dependency upgrade is merged, thus triggering the CI/CD pipeline and, eventually, a service restart. And all of this happens right smack dab in the middle of an event with thousands of active connections. The simulation below illustrates how wild things can get.

Connection avalanche caused by server restart (simulation)

All active connections are dropped during restarts. This is fine, and we use a _smart_ WebSocket client with built-in reconnect capabilities, so, whenever the server is back, the clients try to restore the connection and their states. The problem is that they try to do that all at once—the avalanche is starting! The server is overwhelmed by the number of incoming connect and subscribe commands and it struggles to process them all on time. Some clients may decide that the server is unresponsive, so they terminate the connections as they end and start over—with that, a secondary avalanche kicks off! In the worst-case scenario, the server crashes or is terminated (being unable to respond to health checks), and the whole disaster repeats.

A server restart during a high-crowd event is an example of the recovery avalanche type. The same thing happens when you have many less-crowded events that result in tons of active connections; tt’s the number of clients that reconnect triggering the avalanche. You may also face an avalanche situation without any restarts, but just because many users join a popular event all at the same time (maybe, due to some “The event starts in X seconds” wait-and-reload feature)—that would be an example of the celebrity avalanche type.

Luckily, avalanche prevention measures exist, and we can mitigate the risk of being choked with connections. In this post, we’ll talk about the most helpful methods, divided into four categories, depending on at which level they can be applied:

- [Operations](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#operations)
  - [Deployment windows](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#deployment-windows)
  - [Slow rollouts](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#slow-rollouts)
- [Client](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#client)
  - [Backoff & jitter](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#backoff--jitter)
  - [Linearized subscriptions](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#linearized-subscriptions)
- [Protocol](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#protocol)
  - [Disconnect notices](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#disconnect-notices)
  - [Session resumeability](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#session-resumeability)
  - [Pre-authorized subscriptions](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#pre-authorized-subscriptions)
- [Server](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#server)
  - [Slow-drain disconnection](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#slow-drain-disconnection)
  - [Real-time server as a proxy](https://evilmartians.com/chronicles/connection-avalanche-safety-tips-and-prepping-for-realtime-applications#real-time-server-as-a-proxy)

## Operations

In this section, we’ll discuss safety tips that do not involve code changes, but only how we roll out the code to production. Thus, the following techniques are only useful in dealing with recovery avalanches.

### Deployment windows

Let’s start with something that has been hidden between the lines of our example just a little bit—don’t spoil the (online) party by deploying and restarting your real-time server in the middle of the proceedings. This rule alone works well for applications with a) predictable load and b) non-uniform load. Do you know that you’ll host an online JavaScript conference over the next few days? Better put all rollouts on hold, or consider employing other avalanche prevention techniques.

“What if I need to deploy a hotfix?” Well, let me share a personal story.

Years before Zoom, I worked on a videoconferencing platform for an educational startup. We gradually migrated our clients to this new platform from the proprietary one we had previously used (Adobe Connect, if you were about to ask). Everything went well with our small clients, and we convinced the biggest client to hold a large event using our homegrown software. And you know what? We were just about to mess things up because a crucial bug appeared that we weren’t able to catch during test events of a smaller size.

So, how did we manage to avoid a shameful experience? Our saving grace was that we had the right tool for the job: our real-time server was written in Erlang, and one of Erlang’s superpowers is the ability to reload code without even stopping _actors_ (Erlang lightweight processes). So, I was able to just fix and reload the code in real-time from the server’s terminal during the event—ah, the good old days when programming was fun!

These days, we either bet on more mainstream languages without these code reload capabilities or complicate our infrastructure in a way that hardly makes it possible to mess with the running server process. So, let’s jump back to our question, “How to deploy a hotfix?”, there is no good answer or advice, just another question to ask yourself: Does the fix outweigh the potential UX degradation during the reconnect?

### Slow rollouts

If you operate on a cluster of N real-time servers, you can minimize the avalanche effect by restarting the servers one by one or performing so-called slow rollouts. In the Kubernetes world, this strategy is known as a _ramped slow rollout_ and can be expressed in YAML as follows:

```yml
spec:
  replicas: 7
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

> It’s important to use the Least Connections (or similar) load-balancing strategy to avoid non-uniform distribution of clients during rollouts.

By default, load balancers use a round-robin strategy to route traffic within a cluster. This works well for regular request-response applications, but is far from the best choice for real-time ones that usually rely on persistent connections. This is especially important during deployments, even with rolling updates. With round-robin, some servers can receive too many connections (re-connected from the stopped instances) and consume too many resources, so they could be terminated by the supervisor as misbehaving (or they could simply crash) and that would lead to an avalanche situation (this sentence based on a true story).

Round-robing load balancing (simulation)

## Client

Now, let’s talk about what we can do on the client side to reduce the risk of avalanches.

### Backoff & jitter

The same general medication we use for a thundering herd problem caused by retries can also be applied to connection avalanches, too. Specificially, we can introduce a backoff (e.g., exponential) to reconnection attempts, so clients restart at different times (depending on the attempt number). Making this backoff non-deterministic by introducing a random jitter results in a much better (from the server load perspective) distribution of connecting clients. We ran some experiments a while ago while working on the [AnyCable JS client](https://github.com/anycable/anycable-client) to compare different backoff strategies:

Evaluating reconnect strategies

> Always spice reconnection delays with some randomness to more evenly distribute the load on the server over time.

### Linearized subscriptions

In the example above, we specifically highlighted that a real-time client performs multiple operations during the initialization, not only the network connection establishment but also subscription requests.

How do we usually implement the subscription process in WebSocket clients? We send messages like `{command: "subscribe", channel: "chat/42"}` and wait for an acknowledgment. Real-time communication is usually asynchronous, meaning that subscription requests are sent concurrently (if we want to subscribe to multiple channels). The more subscriptions a client needs the more commands the server receives simultaneously. Do you see what I’m getting at?

> The number of units of work to be accomplished by the server on mass client connections are defined by both the number of clients ( _N_) and the number of subscriptions each client creates ( _S_), and in O-notation could be expressed as _O(NxS)_.

A high number of subscriptions is very common to frameworks that allow subscribing to live updates in a non-centralized way (e.g., from UI components). For instance, **GraphQL Subscriptions** and **Hotwire Turbo Streams** are both this type of framework: you simply drop UI components with `useSubscription` or `<turbo-stream-source>` on the page. We’ve seen applications with such _live components_ representing table cells (!!!)—do not try this at home.

To soothe the effect of a connections spike with regards to subscriptions in both recovery and celebrity avalanche cases, we can limit the number of concurrent subscribe commands (i.e., minimize the _S_ factor). In other words, we can implement some client-side _throttling_ for outgoing subscription requests.

The most basic way to do that is to _linearize subscribe requests_: all outgoing subscribe requests form a queue and the next one is sent only after the previous one has been acknowledged by the server. Thus, the load on the server is distributed over some period of time depending on how quickly the server can process and acknowledge requests.

Linearized subscriptions also help avoid retries that can happen if a server is overloaded and cannot acknowledge requests on time, meaning the client may assume that the subscribe request has been lost though it just hasn’t been processed yet. Ironically, retries that aim to resolve potential issues increase the load on the server even more.

Concurrent vs. linearized subscribes (simulation)

We introduced linearized subscriptions to [AnyCable JS](https://github.com/anycable/anycable-client) to provide a quick and robust solution to this problem for existing applications, and the effect of this feature turned out to be quite positive. We found that, despite delaying subscription requests, the total time to initialize all client subscriptions decreased, in some cases down to 2x compared to the concurrent mode (the more load on the server, the better the improvement).

## Protocol

Let’s move up the stack and talk about the communication line between a client and server, or a _protocol_. Curious what that is? A protocol defines the format (or schema) of the messages sent in both directions between client and server. It usually covers the supported commands and event types. For example, Rails and AnyCable uses [Action Cable protocol](https://docs.anycable.io/misc/action_cable_protocol), Laravel Reverb uses [Pusher Channels protocol](https://pusher.com/docs/channels/library_auth_reference/pusher-websockets-protocol/), and so on.

Protocols may define some features that can help in preventing avalanches. Up next, let’s consider some of them.

### Disconnect notices

For a moment, let’s continue talking about the client-side measures, but now from the server perspective—how can a server help a client make better decisions during reconnects?

One option is to inform the client about the upcoming server restart. The logic behind the reconnect delay can be optimized if it is possible to distinguish server restarts from network failures. This is how, for example, Rails Action Cable does it, by sending a special `{type: "disconnect", reason: "server_restart"}` message to all clients during a shutdown.

A server can also ask the client to cool down for a given period. This allows it to gradually accept all the _avalanching_ clients. This trick can be helpful, not only during restarts, but also to mitigate celebrity avalanches. We can call this technique the _delegated throttling_.

### Session resumeability

We already know that the most load on a server during mass reconnection happens because of client state restoration (authentication, subscriptions). What if instead of having to prove who they are and asking for data streams from scratch our clients could tell the server: “Hey, it’s me, I-330, remember me? Let’s pick up where you left me…” _(said i promise, don’t hold that against me; if you do, let me go)_

To make our server respond “Sure, come on in, I’ve been waiting for you! Here’s what you missed…”, we need to implement a session persistence mechanism at the server side and to enhance the communication protocol with **session resumeability** capabilities:

- Every client must receive a unique _session token_ on the initial connection.
- A client may attach its session token during the subsequent connection attempts.
- A server may respond with the “session_restored” event in case the provided token is valid and the session information is still available; the client then skips re-subscriptions and continues operating as no connection disruption happened.

This feature is supported by many popular real-time servers and PaaS services, such as [AnyCable](https://docs.anycable.io/anycable-go/reliable_streams), [Socket.io](https://socket.io/docs/v4/connection-state-recovery), and [Ably](https://ably.com/docs/connect/states) to name a few. In most cases, this feature is opt-in, so, please, refer to the documentation of your server and see if it’s available (and check potential drawbacks—nothing comes for free).

## Server

Okay, time to talk about what we can do at the back end of things: your real-time server and/or your application.

### Pre-authorized subscriptions

Let’s think for a moment about why (or when) handling tons of subscribe requests could be too much for a server. Any ideas? Let me give you a hint: A—authorization.

Most real-time applications verify access to the stream/channel before confirming or rejecting the subscription attempt. No matter which subscription callback you use,`#subscribed`, `join/3`, `connect(self)`, or whatever, the logic you put inside is what does. Performing a database lookup? Calling external authorization services? All of these are things you’re better off not mass invoking during connection avalanches.

We cannot sacrifice authorization, but we can switch from _pull_ to _push_ mode: instead of evaluating complex access rules on subscribe, we can pre-authorize access, provide some secure token along the subscription request, and verify it on the server-side—and that’s it! (This is exactly how Hotwire Turbo Streams work, by the way.)

What’s good about this technique is that it helps to deal with any avalanche, not just those caused by a server restart.

You can implement this logic yourself or use a similar feature provided by your real-time server or framework. For example, AnyCable supports [signed streams](https://docs.anycable.io/anycable-go/signed_streams), Centrifugo supports [_presibscribing_ clients](https://centrifugal.dev/docs/server/server_subs) to channels.

Similarly, using JWT to authenticate and identify (i.e., provide user information) clients can also help in reducing load during the connection initialization.

### Slow-drain disconnection

Let’s talk about slow rollouts once again. What happens with active connections on the instance we’re shutting down? We disconnect clients as fast as possible taking in-flight commands into account (only if we want to be graceful, of course). Thus, a portion of all active clients ( _1/N_, where _N_ is the number of instances in the cluster) reconnect simultaneously causing a micro-avalanche. When the size of the cluster is small, such micro-avalanches can also be harmful.

We can bring the slow rollout technique to the next level if we _teach_ our real-time server to gradually disconnect active clients over a specified period of time during restarts, not altogether. We (at AnyCable) call this feature [slow drain disconnect mode](https://docs.anycable.io/anycable-go/configuration?id=slow-drain-mode). It has proven to be one of the most efficient ways to prevent recovery avalanches in terms of the amount of refactoring needed (and, thus, engineering time spent).

Slow drain disconnection is also useful when you have to deal with vendored (and not-so-flexible) infrastructure where slow rollouts are hardly (if at all) possible (like Heroku).

### Real-time server as a proxy

Have you heard of the [bulkhead pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead)? It’s an application stability pattern that implies the isolation of critical resources for improved fault tolerance.

The word “isolation” above is the important part for us, and here’s why: the root cause of the connection avalanche problem (at least, its recovery variation) is the fact that we deal with persistent network connections (usually, WebSockets) and their states. Can we use the bulkhead idea to _move_ such a connection outside of our main application to some ~~dumb~~ logic-less, real-time proxy service in order to manage clients and delegate business-logic tasks (like authentication/authorization) to our application? Sure, we can! This is one of the main motivations behind our own [AnyCable](https://evilmartians.com/products/anycable).

AnyCable focuses on one task: maintaining your real-time clients and managing pub/sub subscriptions. It knows nothing about the _nature_ of these subscriptions (like the product meaning behind them or the authorization rules) and it also does not know how you identify your clients. Your application is still in control of the business logic, and you either rely on signed streams and JWT or AnyCable RPC to glue the pieces together.

> Separating real-time and non-real-time infrastructure for your web application is an important step towards higher loads and calmer nights.

![Radio wave representing wind sounds on Mars](Base64-Image-Removed)

To sum up a bit, I’ve shared my personal experience and the sacred and unwritten experience of AnyCable users with regard to the thundering herd problem in real-time applications. So, use this knoweldge like a pamphlet of essential “safety tips” out there in the wild and be fully prepared for any connection avalanches.

One more thing: don’t hesitate to share your tips, tricks, (and horror stories) [with me](https://twitter.com/palkan_tula)! I’d be more than happy to update this post to make it as complete as possible!
