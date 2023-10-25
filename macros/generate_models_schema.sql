{# generate models section entries to add to schema.yml with ready references to the markdown .md file docs blocks #}
{% macro generate_models_schema(models=[]) %}

    {% if models is string %}
        {{ exceptions.raise_compiler_error("The `models` argument must always be a list, even if there is only one model.") }}
    {% else %}

        -- check all_models parameter
        {% if not models %}
            {{ log("NOTE: Parameter 'models': " ~ models|length ~ " ...getting non-*_transform models in the project...", info=True) }}
            {% set project_models = get_project_models() %}
            {% set models_list = [] %}
            {% for proj_mod in project_models %}
                {% if not proj_mod.endswith('_transform') %}
                    {% do models_list.append(proj_mod) %}
                {% endif %}
            {% endfor %}
        {% else %}
            {% set models_list = models %}
        {% endif %}

        {{ log("Build schema sections for models: " ~ models_list, info=True) }}

        {% set models_section_txt = [] %}
        {% do models_section_txt.append('') %}
        {% do models_section_txt.append('version: 2') %}
        {% do models_section_txt.append('') %}
        {% do models_section_txt.append('') %}
        {% do models_section_txt.append('models:') %}

        -- EAX-DE dbt patterns aliases are the actual table names
        {% set column_to_table_aliases = get_column_to_aliases(models_list) %}
        {% set models_details = get_models(models_list) %}
        -- all models declared in project and then query their columns via dbt adapter
        {% set queried_model_columns = get_model_columns(models_list) %}
        
        {% for model in models_details %}
            {% set model_name = model.name %}
            {% set alias_name = model.alias %} 
            {% do models_section_txt.append('') %}
            {% do models_section_txt.append('  - name: ' ~ model_name|lower) %} 
            {% do models_section_txt.append("    description: '{{ doc(" ~ '"' ~ alias_name|lower ~ '"' ~ ") }}'") %}
            
            {% set model_columns = queried_model_columns.get(model_name) %}
            {% if model_columns|length > 0 %}
                {% do models_section_txt.append('    columns:') %}
            {% endif %}

            {% for column_name in model_columns %}
                {% do models_section_txt.append('      - name: ' ~ column_name|lower ) %}
                -- column appears in >1 table / alias names
                {% if column_to_table_aliases.get(column_name)|length > 1 %}
                    {% do models_section_txt.append("        description: '{{ doc(" ~ '"__' ~ column_name|lower ~ '__"' ~ ") }}'") %}
                {% else %}
                    {% do models_section_txt.append("        description: '{{ doc(" ~ '"' ~ column_name|lower ~ '"' ~ ") }}'") %}
                {% endif %}
            {% endfor %}

        {% endfor %}

    {% endif %}

{% if execute %}

    {% set joined = models_section_txt | join ('\n') %}
    {{ log(joined, info=True) }}
    {% do return(joined) %}

{% endif %}

{% endmacro %}