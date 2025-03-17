# Websearch

This example shows how to use LLM to search the web.

## Key points:

- We pass to a model list of domains we want to search for to avoid poor quality of results. This is useful because autonomous browsing of web pages quickly leads to low-quality sources or services that require logging in or blocking access to content.
- Model decides if the search is needed, which domain should be searched and generates a query based on user query.
- Then we scrap a page, score the result and return the answer
