-- Gets all the model names in a project
{% macro get_project_models() %}
    
    {% set project_models = [] %}

    {% for model in graph.nodes.values() | selectattr('resource_type', "equalto", 'model') %}
        {% do project_models.append(model.name) %}
    {% endfor %}

{% if execute %}
    {{ log(project_models, info=True) }}
    {% do return(project_models) %}
{% endif %}
{% endmacro %}

-- Retrieve the details of a specific list of models
{% macro get_models(models=[]) %}

    {% set models_list = [] %}
    {% for given_model in models %}
        {% for model in graph.nodes.values() | selectattr('resource_type', "equalto", 'model') %}
            {% if model.name|lower == given_model|lower %}
                {% do models_list.append(model) %}
            {% endif %}
        {% endfor %}
    {% endfor %}
    {{ return(models_list) }}
{% endmacro %}

-- get list of all tests configured in the project
{% macro get_tests() %}

    {% set all_tests = [] %}
    {% for test in graph.nodes.values() | selectattr('resource_type', "equalto", 'test') %}
        {% do all_tests.append(
                {
                    'test_name': test.get('name'),
                    'severity': test.get('config').get('severity')|lower ,
                    'warn_if' : test.get('config').get('warn_if'),
                    'error_if' : test.get('config').get('error_if'), 
                    'depends_on': test.get('depends_on'),
                    'column_name': test.get('column_name'),
                    'description': test.get('config').get('description'),
                    'meta': test.get('config').get('meta')
                }) %}
    {% endfor %}

    {{ return(all_tests) }}
{% endmacro %}

-- simply get a dictionary of all of a model's column descriptions
{% macro get_column_descriptions(models=[], model_name='') %}

    {% set column_descriptions = {}%}
    {% set models_list = get_models(models) %}
    {% for model in models_list %}
        {% if model_name == model.name %}
            {% set column = model.columns %}
            {% for column_name, column_details in column.items() %}
                {% do column_descriptions.update({column_name: column_details.description}) %}
            {% endfor %}
        {% endif %}
    {% endfor %}
    {{ return(column_descriptions) }}
{% endmacro %}


-- retrieve data from adapter to enrich data from graph (existing)
{% macro get_model_columns(models=[]) %}

    {% set model_to_columns_dict = {} %}
    -- get all models declared in graph
    {% set models = get_models(models) %}
    {% for model in models %}
        {% set model_name = model.name | lower %}
        {% set columns_list = [] %}
        {% set relation = ref(model_name) %}

        {% set columns = adapter.get_columns_in_relation(relation) %}
        {% for column in columns %}
            {% do columns_list.append(column.name|lower) %}
        {% endfor %}
        -- store all columns obtained from adapter object in model_to_columns_dict
        {% if model_name in model_to_columns_dict %}
            {% set model_columns = model_to_columns_dict.get(model_name) %}
            {% for c in columns_list %}
                {% do model_columns.append(c) %}
            {% endfor %}
            {% do model_to_columns_dict.update({model_name: set(model_columns)|list}) %}
        {% else %}  -- create new key, value entry in model_to_columns_dict
            {% do model_to_columns_dict.update({model_name: set(columns_list)|list}) %}
        {% endif %}
    {% endfor %}

    {{ return(model_to_columns_dict) }}
{% endmacro %}

/* CRITICAL COMPONENT builds the dictionary of unique alias names (key) in the project and the related colum names as a
list (value). Combine existing graph content with with up-to-date information from adapater query*/
{% macro get_alias_to_columns(models=[]) %}

    {% set alias_to_columns_dict = {} %}
    -- get all models declared in graph
    {% set models = get_models(models) %}
    {% for model in models %}
        {% set model_name = model.name | lower %}
        {% set alias_name = model.alias | lower %}
        {% set columns_list = [] %}
        {% set relation = ref(model_name) %}

        {% set columns = adapter.get_columns_in_relation(relation) %}
        {% for column in columns %}
            {% do columns_list.append(column.name|lower) %}
        {% endfor %}
        -- store all columns obtained from adapter object to alias_to_columns_dict
        {% if alias_name in alias_to_columns_dict %}
            {% set alias_columns = alias_to_columns_dict.get(alias_name) %}
            {% for c in columns_list %}
                {% do alias_columns.append(c) %}
            {% endfor %}
            {% do alias_to_columns_dict.update({alias_name: set(alias_columns)|list}) %}
        {% else %}  -- create new key, value entry in alias_to_columns_dict
            {% do alias_to_columns_dict.update({alias_name: set(columns_list)|list}) %}
        {% endif %}
    {% endfor %}

    {{ return(alias_to_columns_dict) }}
{% endmacro %}


/* CRITICAL COMPONENT builds the dictionary of unique column names in the project and the aliases/table names 
   where they are used. if a col_a is related to >1 aliases then review for DRY-ness of docs.md and schema.yml */
{% macro get_column_to_aliases(models=[]) %}
    {% set column_to_aliases_dict = {} %}
    -- get all models
    {% set models = get_models(models) %}
    {% for model in models %}
        {% set model_name = model.name | lower %}
        {% set alias_name = model.alias | lower %}
        -- query the ref(model.name) via adapter objet
        {% set relation = ref(model_name) %}

        {% set columns = adapter.get_columns_in_relation(relation) %}
        -- store all columns obtained from adapter object to column_to_alias to check 
        {% for column in columns %}

            {% set column_name = column.name | lower %}
            {% if column_name in column_to_aliases_dict %}
                -- get the current aliases list from the dictionary...
                {% set alias_list = column_to_aliases_dict.get(column_name) %}
                {% if alias_name not in alias_list %}
                    {% do alias_list.append(alias_name) %}
                {% endif %}
                {% do column_to_aliases_dict.update({column_name: alias_list}) %}
            {% else %} -- create new key, value entry
                {% do column_to_aliases_dict.update({column_name : [alias_name]}) %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {{ return(column_to_aliases_dict) }}
{% endmacro %}

-- used only in generate_docsblocks
{% macro generate_alias_column_description(models=[], column_name='', docsblocks_txt=[]) %}
    -- collect the column descriptions for each of the models with matching alias
    {% set column_descriptions = {} %}

    {% set models_list = get_models(models) %}
    {% for model in models_list %}
        {% set model_column_descriptions = get_column_descriptions(models, model.name) %}
        {% set column_name_desc = model_column_descriptions.get(column_name) %}
        {% if not column_name_desc in ['', None, '__column_description__'] %}
            {% if not column_name_desc in column_descriptions %}
                {% do column_descriptions.update({column_name_desc : [model.name]}) %}
            {% else %}
                {% set updated_col_desc_models = column_descriptions.get(column_name_desc) + [model.name] %}
                {% do column_descriptions.update({column_name_desc : updated_col_desc_models}) %}
            {% endif %}
        {% endif %}
    {% endfor %}

    -- now update the docsblock_txt
    {% if not(column_descriptions) %}
        {% do docsblocks_txt.append('__column_description__') %}
    {% else %}
        {% for col_desc, v_models in column_descriptions.items() %}
            {% if column_descriptions|length > 1 %}
                {% do docsblocks_txt.append('') %}
                {% do docsblocks_txt.append('[@ ' ~ ", ".join(v_models) ~ ' ]: #') %}
            {% endif %}
            {% do docsblocks_txt.append(col_desc) %}
        {% endfor %}
    {% endif %}

    {{ return(docsblocks_txt) }}
{% endmacro %}

-- used only in generate_docsblocks
{% macro generate_alias_descriptions(models=[], alias_name='', docsblocks_txt=[]) %}

    {% set alias_descriptions = {} %}

    {% set models_list = get_models(models) %}
    {% for model in models_list %}
        {% if alias_name == model.alias %}
            {% set alias_desc = model.description %}
            {% if not alias_desc in ['', None, '__table_description__'] %}
                {% if not alias_desc in alias_descriptions %}
                    {% do alias_descriptions.update({alias_desc : [model.name]}) %}
                {% else %}
                    {% set updated_alias_desc_models = alias_descriptions.get(alias_desc) + [model.name] %}
                    {% do alias_descriptions.update({alias_desc : updated_alias_desc_models}) %}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endfor %}

    -- now update the docsblock_txt
    {% if not(alias_descriptions) %}
        {% do docsblocks_txt.append('__table_description__') %}
    {% else %}
        {% for desc_alias, v_models in alias_descriptions.items() %}
            {% if alias_descriptions|length > 1 %}
                {% do docsblocks_txt.append('') %}
                {% do docsblocks_txt.append('[@ ' ~ ", ".join(v_models) ~ ' ]: #') %}
            {% endif %}
            {% do docsblocks_txt.append(desc_alias) %}
        {% endfor %}
    {% endif %}

    {{ return(docsblocks_txt) }}
{% endmacro %}
