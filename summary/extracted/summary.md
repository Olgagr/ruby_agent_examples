# Connection Avalanche Safety Tips and Prepping for Real-Time Applications

Launching a greenfield application or rolling out a new feature can be like going out into the wilderness: you can never quite be sure what is waiting for you out there. Today, I’d like to talk about one such problem: the **thundering herd problem**, as it relates to real-time applications. We’ll discuss how you can minimize risks by following some simple safety rules.

## What is the thundering herd problem?

A thundering herd incident is a sudden influx of the number of simultaneous requests which overwhelms server resources and causes significant system lags, crashes, and, thus, cascading failures. This influx can arise from various causes:

- **Recovery issue**: A burst of traffic occurs when a service that was unavailable comes back online, prompting downstream services to retry all the failed requests.
- **Celebrity issue**: A popular user posting an update can lead to a spike in requests from followers, resulting in a massive surge of traffic.

For example, there is the _cache stampede_ problem; this is a situation where many clients concurrently request a resource missing in the distributed cache and cause high numbers of upstream requests. In the world of real-time applications, we also have our specific version of the thundering herd problem: connection avalanches.

### Characteristics of real-time applications

Real-time applications serve **persistent, long-lived, stateful clients**, requiring constant, often bi-directional communication with the server. The initialization process usually involves authentication, authorization, and subscribing to multiple data streams—quite a number of operations to be performed by the server. Upon connecting, the server must verify the client’s authenticity and access to the event; as this handshake succeeds, the client concurrently subscribes to different data streams: messaging, presence (a list of users), media events (play/pause, new media, and so on), and, probably, a few more (e.g., analytics). Consider an online events platform like [Vito](https://vi.to/), where thousands of clients connect to receive updates during live events. If a server restart occurs during a high-traffic event, all active connections drop, and clients attempt to reconnect simultaneously, initiating a connection avalanche.

## Avalanche prevention measures

To mitigate connection avalanches, various strategies can be applied, categorized by the level at which they can be implemented: Operations, Client, Protocol, and Server.

### Operations

#### Deployment windows

Avoid deploying or restarting your real-time server during high-traffic events to prevent recovery avalanches. For applications with predictable loads, it is crucial to hold off on rollouts during significant events.

#### Slow rollouts

When operating on a cluster of real-time servers, minimize the avalanche effect by restarting servers one by one, known as slow rollouts. Using a load-balancing strategy such as Least Connections can help avoid non-uniform distribution of clients during rollouts.

### Client

#### Backoff & jitter

Introduce backoff strategies (e.g., exponential) to reconnection attempts, allowing clients to restart at different times. Adding random jitter results in a better distribution of connecting clients, reducing server load.

#### Linearized subscriptions

Limit the number of concurrent subscription requests by implementing client-side throttling. Queue outgoing subscribe requests so that the next one is sent only after the previous one has been acknowledged by the server, distributing the load over time.

### Protocol

#### Disconnect notices

Inform clients about upcoming server restarts to help them manage reconnection attempts more effectively. This allows the server to gradually accept reconnecting clients, helping to mitigate avalanches. Delegated throttling can be employed here to further manage the load.

#### Session resumeability

Implement session persistence mechanisms that allow clients to reconnect using a unique session token, bypassing the need for re-authentication and resubscribing to data streams, thereby reducing server load.

### Server

#### Pre-authorized subscriptions

To minimize the load during connection avalanches, pre-authorize access to streams before confirming subscription attempts. This can be achieved through secure tokens or JWT for client authentication.

#### Slow-drain disconnection

Gradually disconnect active clients over a specified period during server restarts to prevent micro-avalanches. This can be particularly effective in environments where slow rollouts are challenging.

#### Real-time server as a proxy

Utilize a real-time server as a proxy to manage client connections separately from the main application logic. This separation helps improve stability and load management.

## Conclusion

The thundering herd problem poses significant challenges for real-time applications, especially during high-load scenarios. By employing the outlined strategies across operations, client, protocol, and server levels, developers can better prepare their applications for potential connection avalanches. Share your tips and experiences [on Twitter](https://twitter.com/palkan_tula) to contribute to a more comprehensive understanding of this issue.
