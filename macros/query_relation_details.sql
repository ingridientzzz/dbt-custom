{# this macro retrieves information schema columns for the descriptions for a relation, always pass in a list of relation names #}
{% macro query_relation_details(relation_names=[]) %}

{% if execute %}

    {% if relation_names is string %}
        {{ exceptions.raise_compiler_error("The `relation_names` argument must always be a non-empty list, even if there is only one relation.") }}
    {% elif relation_names|length == 0 %}
        {{ exceptions.raise_compiler_error("Parameter 'relation_names' not provided. Indicate a non-empty list of relation names.") }}
    {% endif %}

    {% set content_txt = [] %}
    {% do content_txt.append('') %}

    {% for relation in relation_names %}
        -- Breakdown the relation name in parts...
        {% set relation_db = relation.split('.')[0] %}           -- get first
        {% set relation_schema = relation.split('.')[1]%}        -- get second
        {% set relation_identifier = relation.split('.')[-1] %}  -- get last

        {% do content_txt.append('## ' ~ relation) %}

        -- SQL template to retrieve the table comment/description from Snowflake
        {% set table_info_schema_sql %}
            SELECT
                "comment"
                , table_type
            FROM {{ relation_db|upper }}.INFORMATION_SCHEMA.TABLES
            -- Upper case because Snowflake stores the names in this format
            WHERE table_name = {{ "'" ~ relation_identifier|upper ~ "'" }}
                AND table_schema = {{ "'" ~ relation_schema|upper ~ "'" }}
        {% endset %}
        -- Get the table description & store as table_comment
        {% set result_table = run_query(table_info_schema_sql) %}
        {% if result_table|length == 0 %}
            {% set log_message = "TABLE_NAME = '" ~ relation_identifier|upper ~ 
                                "' & TABLE_SCHEMA = '" ~ relation_schema|upper ~ 
                                "' in " ~ relation_db|upper ~ '.INFORMATION_SCHEMA.TABLES' %}
            {{ log("[NOT FOUND]: " ~ log_message, info=True) }}
        {% endif %}

        {% set table_type = result_table.columns[1].values()[0] %}
        {% set table_comment = result_table.columns[0].values()[0] %}

        {% do content_txt.append('### Table Type : ' ~ table_type) %}
        {% do content_txt.append('### Description:') %}

        {% if not (table_comment|string).strip() in ['None', ''] %}
            {% do content_txt.append('```') %}
            {% do content_txt.append('{% docs ' ~ relation_schema|lower ~ '_' ~ relation_identifier|lower ~ ' %}') %}
            {% do content_txt.append( table_comment ) %}
            {% do content_txt.append('{% enddocs %}') %}
            {% do content_txt.append('```') %}
        {% else %}
            {% do content_txt.append(None) %}
        {% endif %}

        -- SQL template retrieve the column coment/description from Snowflake
        {% set column_info_schema_sql %}
            SELECT
                column_name
                , "comment"
                , data_type
            FROM {{ relation_db|upper }}.INFORMATION_SCHEMA.COLUMNS
            -- Upper case because Snowflake stores the names in this format
            WHERE table_name = {{ "'" ~ relation_identifier|upper ~ "'" }}
                AND table_schema = {{ "'" ~ relation_schema|upper ~ "'" }}
        {% endset %}
        -- Get the column descriptions...
        {% set results_columns = run_query(column_info_schema_sql) %}
        {% if result_table|length == 0 %}
            {% set log_message = "TABLE_NAME = '" ~ relation_identifier|upper ~ 
                                "' & TABLE_SCHEMA = '" ~ relation_schema|upper ~ 
                                "' in " ~ relation_db|upper ~ '.INFORMATION_SCHEMA.COLUMNS' %}
            {{ log("[NOT FOUND]: " ~ log_message, info=True) }}
        {% endif %}

        {% set columns = results_columns.columns[0].values() %}
        {% set column_comments = results_columns.columns[1].values() %}
        {% set column_data_types = results_columns.columns[2].values() %}
        
        {% do content_txt.append('### Columns : ' ~ columns|length ) %}
        -- store column_data_type in a data_type dict
        {% set col_source_data_type = dict(zip(columns, column_data_types)) %}
        -- ...and store results in column_descriptions dict
        {% set col_source_desc = zip(columns, column_comments) %}
        {% for k, v in col_source_desc %}
            {% if not (v|string).strip() in ['None', ''] %}
                {% do content_txt.append('- ' ~ k|lower ~ ' (' ~ col_source_data_type.get(k) ~ '):') %}
                {% do content_txt.append('```') %}
                {% do content_txt.append('{% docs ' ~ k|lower ~ ' %}') %}
                {% do content_txt.append( v ) %}
                {% do content_txt.append('{% enddocs %}') %}
                {% do content_txt.append('```') %}
            {% else %}
                {% do content_txt.append('  - ' ~ k|lower ) %}    -- column name
            {% endif %}
        {% endfor %}
        {% do content_txt.append('') %}
        
    {% endfor %}

    {% set joined = content_txt | join ('\n') %}
    {{ log(joined, info=True) }}
    {% do return(joined) %}

{% endif %}

{% endmacro %}