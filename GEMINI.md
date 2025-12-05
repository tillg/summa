# Gemini Integration

This document outlines how to interact with Gemini models within this project, covering the core `GeminiModel` class, the `Gemini` integration, and schema conversion utilities.

## 1. GeminiModel Usage

The `GeminiModel` class provides a simplified interface for calling Gemini models, including support for parallel requests and retry logic.

### Initialization

You can initialize `GeminiModel` with various parameters:

```python
class GeminiModel:
    def __init__(
        self,
        model_name: str = "gemini-2.0-flash-001",
        finetuned_model: bool = False,
        distribute_requests: bool = False,
        cache_name: str | None = None,
        temperature: float = 0.01,
        **kwargs,
    ):
        # ...
```

-   `model_name`: Specifies the Gemini model to use (default: "gemini-2.0-flash-001").
-   `finetuned_model`: Set to `True` if using a finetuned model.
-   `distribute_requests`: If `True` and not a finetuned model, requests might be distributed across different regions.
-   `cache_name`: Optional name for cached content.
-   `temperature`: Controls the randomness of the output (default: 0.01).

### Making a Single Call

Use the `call` method to send a single prompt to the Gemini model.

```python
    @retry(max_attempts=12, base_delay=2, backoff_factor=2)
    def call(self, prompt: str, parser_func=None) -> str:
        """Calls the Gemini model with the given prompt.

        Args:
            prompt (str): The prompt to call the model with.
            parser_func (callable, optional): A function that processes the LLM
              output. It takes the model"s response as input and returns the
              processed result.

        Returns:
            str: The processed response from the model.
        """
        # ...
```

Example:

```python
from your_module import GeminiModel

gemini_model = GeminiModel(model_name="gemini-1.5-flash")
response = gemini_model.call("Tell me a story about a brave knight.")
print(response)

def custom_parser(text):
    return text.upper()

response_parsed = gemini_model.call("Hello world", parser_func=custom_parser)
print(response_parsed) # HELLO WORLD
```

### Making Parallel Calls

For multiple prompts, use `call_parallel` to send them concurrently with retry logic.

```python
    def call_parallel(
        self,
        prompts: List[str],
        parser_func: Optional[Callable[[str], str]] = None,
        timeout: int = 60,
        max_retries: int = 5,
    ) -> List[Optional[str]]:
        """Calls the Gemini model for multiple prompts in parallel using threads with retry logic.

        Args:
            prompts (List[str]): A list of prompts to call the model with.
            parser_func (callable, optional): A function to process each response.
            timeout (int): The maximum time (in seconds) to wait for each thread.
            max_retries (int): The maximum number of retries for timed-out threads.

        Returns:
            List[Optional[str]]:
            A list of responses, or None for threads that failed.
        """
        # ...
```

Example:

```python
from your_module import GeminiModel

gemini_model = GeminiModel(model_name="gemini-1.5-flash")
prompts = [
    "What is the capital of France?",
    "Who painted the Mona Lisa?",
    "What is 2+2?"
]
responses = gemini_model.call_parallel(prompts)
for i, res in enumerate(responses):
    print(f"Prompt {i+1}: {prompts[i]} -> Response: {res}")
```

## 2. Gemini Integration (`Gemini` class)

The `Gemini` class provides a more comprehensive integration with Gemini models, supporting asynchronous calls, streaming, and different API backends (Vertex AI, Gemini API).

### Initialization

```python
class Gemini(BaseLlm):
  """Integration for Gemini models.

  Attributes:
    model: The name of the Gemini model.
  """
  model: str = 'gemini-1.5-flash'
  # ...
```

You can instantiate it directly, often configured with a default model.

### Supported Models

The `supported_models` method lists the patterns for models supported by this integration:

```python
  @staticmethod
  @override
  def supported_models() -> list[str]:
    """Provides the list of supported models.

    Returns:
      A list of supported models.
    """
    return [
        r'gemini-.*',
        # fine-tuned vertex endpoint pattern
        r'projects\/.+\/locations\/.+\/endpoints\/.+',
        # vertex gemini long name
        r'projects\/.+\/locations\/.+\/publishers\/google\/models\/gemini.+',
    ]
```

This includes generic Gemini models, finetuned Vertex AI endpoints, and Vertex Gemini long names.

### Asynchronous Content Generation

The `generate_content_async` method handles asynchronous requests, with an option for streaming responses.

```python
  async def generate_content_async(
      self, llm_request: LlmRequest, stream: bool = False
  ) -> AsyncGenerator[LlmResponse, None]:
    """Sends a request to the Gemini model.

    Args:
      llm_request: LlmRequest, the request to send to the Gemini model.
      stream: bool = False, whether to do streaming call.

    Yields:
      LlmResponse: The model response.
    """
    # ...
```

This method is designed for more advanced use cases where `LlmRequest` and `LlmResponse` objects are used, and streaming might be desired.

## 3. Schema Conversion Utilities

The project includes functions to convert between Gemini `Schema` objects and JSON Schema dictionaries.

### `gemini_to_json_schema`

Converts a Gemini `Schema` object to a JSON Schema dictionary.

```python
def gemini_to_json_schema(gemini_schema: Schema) -> Dict[str, Any]:
  """Converts a Gemini Schema object into a JSON Schema dictionary."""
  # ...
```

### `_to_gemini_schema`

Converts an OpenAPI schema dictionary to a Gemini `Schema` object.

```python
def _to_gemini_schema(openapi_schema: dict[str, Any]) -> Schema:
  """Converts an OpenAPI schema dictionary to a Gemini Schema object."""
  # ...
```

These utilities are crucial for defining and validating data structures when working with tools and function calling capabilities of Gemini models.

---
This document provides a high-level overview. For detailed usage, refer to the source code of `GeminiModel`, `Gemini`, and the schema conversion functions.
