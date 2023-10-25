{# generate docs blocks contents of a centralised markdown .md file with option to include any existing descriptions #}
{% macro generate_docsblocks(models=[], reuse_descriptions=True) %}

    {% if models is string %}
        {{ exceptions.raise_compiler_error("The `models` argument must always be a list, even if there is only one model.") }}
    {% else %}

        -- check if all_models parameter
        {% if not models %}
            {{ log("NOTE: Parameter 'models': " ~ models|length ~ " ...getting models in the project...", info=True) }}
            {% set models_list = get_project_models() %}
        {% else %}
            {% set models_list = models %}
        {% endif %}
        
        {{ log("Build docs blocks for models: " ~ models_list, info=True) }}

        {% set docsblocks_txt = [] %}
        {% do docsblocks_txt.append('') %}
        -- list the tables in the project : EAX-DE dbt patterns aliases are the actual table names
        {% set alias_to_columns = get_alias_to_columns(models_list) %}
        {% do docsblocks_txt.append('### Models: ' ~ models_list|length ~ ' | Unique Alias Names: '  ~  alias_to_columns|length ) %}    

        {% for alias_name in alias_to_columns.keys() %}
            
            {% do docsblocks_txt.append('{% docs ' ~ alias_name|lower ~ ' %}') %}
            -- alias / table descriptions
            {% if reuse_descriptions == True %}
                {% set docsblocks_txt = generate_alias_descriptions(models_list, alias_name, docsblocks_txt) %}
            {% else %}  -- if not getting alias descriptions
                {% do docsblocks_txt.append('__table_description__') %}
            {% endif %} 

            {% do docsblocks_txt.append('{% enddocs %}') %}
            {% do docsblocks_txt.append('') %}
        {% endfor %}
        
        {% do docsblocks_txt.append('') %}  

        -- list the columns, goal output if column appears in >1 aliases
        {% set column_to_table_aliases = get_column_to_aliases(models_list) %}
        {% do docsblocks_txt.append('### Unique Column Names : ' ~ column_to_table_aliases|length ) %}
        
        -- list the columns, sorted alphabetically
        {% for column_name in column_to_table_aliases.keys()|sort %}
            {% set column_aliases = column_to_table_aliases.get(column_name) %}
            -- if a column appears in >1 aliases / tables, candidate for review
            {% if column_aliases|length >1 %}
                {% do docsblocks_txt.append('<!-- common to aliases: ' ~ ", ".join(column_aliases) ~ ' -->') %}
                {% do docsblocks_txt.append('{% docs __' ~ column_name ~ '__ %}') %}
            {% else %}
                {% do docsblocks_txt.append('{% docs ' ~ column_name ~ ' %}') %}
            {% endif %}
            
            -- column descriptions
            {% if reuse_descriptions == True %}
                {% set docsblocks_txt = generate_alias_column_description(models_list, column_name, docsblocks_txt) %}
            {% else %}
                {% do docsblocks_txt.append('__column_description__') %}
            {% endif %}
            {% do docsblocks_txt.append('{% enddocs %}') %}
            {% do docsblocks_txt.append('') %}
        {% endfor %}

    {% endif %}

{% if execute %}

    {% set joined = docsblocks_txt | join ('\n') %}
    {{ log(joined, info=True) }}
    {% do return(joined) %}

{% endif %}

{% endmacro %}