# Chat Summary

This technique is useful to keep the attention of the model and optimize the cost of the model.

## Key points

- Thanks to summarization, the model processes less content, **which makes its attention more focused on the current task** — **IMPORTANT!** in GPT-4o models, this is a very important factor, affecting the model's effectiveness
- Summarization also helps to avoid the context window limit, which is important in Open Source models that can handle the selected interaction element
- Summarization can also be used in other parts of the agent's logic, as well as in the user interface or work report of the agent
- You can use cheaper models to generate the summary and optimize the cost
