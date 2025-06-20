# Create custom LLM wrapper for exo
py_run_string("
import re
import json
from typing import Any, Dict, List, Optional, Iterator
from langchain_openai import ChatOpenAI
from langchain_core.messages import BaseMessage, AIMessage, ToolCall
from langchain_core.outputs import ChatGeneration, ChatResult
from langchain_core.language_models.chat_models import BaseChatModel

class ExoLLMWrapper(ChatOpenAI):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def _generate(self, messages, stop=None, run_manager=None, **kwargs):
        # Call the parent method to get the response
        result = super()._generate(messages, stop, run_manager, **kwargs)
        
        # Process the response to extract tool calls
        for generation in result.generations:
            if hasattr(generation, 'message') and hasattr(generation.message, 'content'):
                content = generation.message.content
                
                # Look for tool calls in the exo format (fixed regex)
                tool_call_pattern = r'<\\|python_tag\\|>(\\{.*?\\})<\\|eom_id\\|>'
                match = re.search(tool_call_pattern, content)
                
                if match:
                    try:
                        tool_data = json.loads(match.group(1))
                        tool_name = tool_data.get('name')
                        tool_args = tool_data.get('parameters', {})
                        
                        # Generate a unique ID for the tool call
                        tool_id = f'call_{abs(hash(content)) % 1000000}'
                        
                        # Create proper tool call object
                        tool_call = ToolCall(
                            name=tool_name,
                            args=tool_args,
                            id=tool_id,
                            type='tool_call'  # Add the type field
                        )
                        
                        # Update the message with proper tool calls
                        generation.message.tool_calls = [tool_call]
                        generation.message.additional_kwargs = {
                            'tool_calls': [{
                                'id': tool_id,
                                'function': {
                                    'name': tool_name,
                                    'arguments': json.dumps(tool_args)
                                },
                                'type': 'function',
                                'index': 0  # Add index field
                            }]
                        }
                        
                        # Clean the content
                        # First remove the python tag
                        clean_content = re.sub(tool_call_pattern, '', content)
                        # Remove header tags
                        clean_content = re.sub(r'<\\|start_header_id\\|>.*?<\\|end_header_id\\|>', '', clean_content)
                        # Remove end of text tag
                        clean_content = re.sub(r'<\\|eot_id\\|>', '', clean_content)
                        # Remove extra whitespace and newlines
                        clean_content = clean_content.strip()
                        
                        # Set content to empty string if it's just describing the tool call
                        # (to match the groq format where content is empty)
                        if 'function call' in clean_content.lower() or 'will return' in clean_content.lower():
                            generation.message.content = ''
                        else:
                            generation.message.content = clean_content
                        
                        # Add usage metadata if available
                        if hasattr(generation.message, 'response_metadata') and generation.message.response_metadata:
                            token_usage = generation.message.response_metadata.get('token_usage', {})
                            if token_usage:
                                generation.message.usage_metadata = {
                                    'input_tokens': token_usage.get('prompt_tokens', 0),
                                    'output_tokens': token_usage.get('completion_tokens', 0),
                                    'total_tokens': token_usage.get('total_tokens', 0)
                                }
                        
                    except (json.JSONDecodeError, KeyError) as e:
                        # If parsing fails, leave the message as is
                        print(f'Failed to parse tool call: {e}')
                        pass
        
        return result
    
    def bind_tools(self, tools):
        # Override bind_tools to ensure it returns an instance that processes tool calls correctly
        bound = super().bind_tools(tools)
        # Ensure the bound model uses our custom _generate method
        bound._generate = self._generate
        return bound
")

# Get the custom wrapper class
ExoLLMWrapper <- py$ExoLLMWrapper

# instantiate it against your Exo endpoint
theLLM <- ExoLLMWrapper(
  model_name            = modelName,
  openai_api_base       = exo_url,
  temperature           = 0.01,
  streaming             = TRUE
)
