# Summary

This script is an example how you can use LLMs to prepare fine-tuned summary of an artice.

## Key points

- User passes the link to the article.
- We download an article in the markdown format.
- First we extract key takeaways, links, context, main topic etc. and we save these extracted data into files, in case we are interested in that.
- Next we extract all images and prepare their visual descriptions and their context description.
- We ask LLM to create a draf summary.
- Next we ask LLM to prepare a critique based of the draft base on original article.
- In the last step, we ask to prepare the final summary based on previous steps.

## Requirements

To run the script, you need:

- OPENAI_API_KEY
- FIRECRAWL_API_KEY
- LNGFUSE_PUBLIC_API_KEY
- LANGFUSE_SECRET_API_KEY
