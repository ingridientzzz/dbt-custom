{# this will give a summary of the project, table or alias names, columns and which tables they are referenced in and also tests configured #}
{% macro inspect() %}

    {% set models = [] %}
    {% for model in graph.nodes.values() | selectattr('resource_type', "equalto", 'model') %}
        {% do models.append(model.name) %}
    {% endfor %}

    {% set summary_report = [] %}
    {% do summary_report.append('') %}

    {% set all_models = get_models(models) %}
    {% set alias_to_cols = get_alias_to_columns(models) %}
    {% set column_to_alias = get_column_to_aliases(models) %}
    {% set all_tests = get_tests() %}
    {% set all_sources = get_sources()%}

    -- list the columns candidate for review
    {% do summary_report.append('## column to alias / table names') %}
    {% do summary_report.append('### nbr of columns parsed: ' ~ column_to_alias.keys()|length ) %}
    {% do summary_report.append('') %}

    {% for col in column_to_alias.keys()|sort %}
    {% set col_alias_list = column_to_alias.get(col) %}
    {% do summary_report.append('- ' ~ col ~ ' :') %}
        {% for col_alias in col_alias_list|sort %}
        {% do summary_report.append('  - ' ~ col_alias ) %}
        {% endfor %}
    {% do summary_report.append('') %}
    {% endfor %}

    {% do summary_report.append('') %}
    {% do summary_report.append('## OTHER DETAILS:') %}
    -- sources configured and freshness checks if any --
    {% do summary_report.append('') %}
    {% do summary_report.append('### sources configured in the project: ' ~ all_sources|length ) %}
    {% for src in all_sources %}
        {% do summary_report.append('') %}
        {% do summary_report.append('- ' ~ src.get('relation_name') ~ ':') %}
        {% set warn_after_count = src.get('freshness').get('warn_after').get('count') %}
        {% set error_after_count = src.get('freshness').get('error_after').get('count') %}
        {% if warn_after_count != None or error_after_count != None %}
            {% do summary_report.append('  - source freshness:') %}
            {% if warn_after_count != None %}
                {% set warn_after_period = src.get('freshness').get('warn_after').get('period') %}
                {% do summary_report.append('    - warn_after: ' ~ warn_after_period ~ ' -> ' ~ warn_after_count) %}
            {% endif %}
            {% if error_after_count != None %}
                {% set error_after_period = src.get('freshness').get('error_after').get('period') %}
                {% do summary_report.append('    - error_after: ' ~ error_after_period ~ ' -> ' ~ error_after_count) %}
            {% endif %}
            {% do summary_report.append('    - filter: ' ~ src.get('freshness').get('filter')) %}
        {% endif %}
    {% endfor %}
    -- tests configured --
    {% do summary_report.append('') %}
    {% do summary_report.append('### tests configured in the project: ' ~ all_tests|length ) %}
    {% for test in all_tests %}
        {% do summary_report.append('- ' ~ test.get('test_name')) %}
        {% do summary_report.append('  - depends_on:') %}
        {% for node in set(test.get('depends_on').get('nodes'))|list %}
            {% set resource_type = node.split('.')[0] %}
            {% if resource_type == 'source' %}
                {% do summary_report.append('    - ' ~ resource_type ~ ': ' ~ node.split('.')[-2] ~ '.' ~ node.split('.')[-1] ) %}
            {% else %}
                {% do summary_report.append('    - ' ~ resource_type ~ ': ' ~ node.split('.')[-1] ) %}
            {% endif %}
        {% endfor %}
        {% if test.get('warn_if') == '!= 0' or test.get('error_if') == '!= 0' %}
            {% do summary_report.append('  - severity: ' ~ test.get('severity')) %}
        {% else %}
            {% do summary_report.append('  - severity: ') %}
            {% do summary_report.append('    - warn_if: ' ~ test.get('warn_if')) %}
            {% do summary_report.append('    - error_if: ' ~ test.get('error_if')) %}
        {% endif %}
        {% do summary_report.append('  - column: ' ~ test.get('column_name')) %}
        {% do summary_report.append('') %}
    {% endfor %}

    -- number of aliases or tables
    {% do summary_report.append('') %}
    {% do summary_report.append('### nbr of tables parsed: ' ~ alias_to_cols|length ) %}
    {% for alias_name in alias_to_cols|sort %}
        {% do summary_report.append('- ' ~ alias_name) %}
        {% for model in all_models %}
            {% if alias_name == model.get('alias') %}
                {% do summary_report.append('  - relation_name : ' ~ model.get('relation_name')|lower ) %}
                {% if model.get('depends_on').get('nodes') %}
                    {% do summary_report.append('    - depends_on: ') %}
                    {% for upstream in model.get('depends_on').get('nodes') %}
                        {% do summary_report.append('      - ' ~ upstream.split('.')[0] ~ ': ' ~ upstream.split('.')[-1] ) %}
                    {% endfor %}
                {% endif %}
            {% endif %}
        {% endfor %}
        {% do summary_report.append('') %}
    {% endfor %}
    {% do summary_report.append('') %}
    -- list the alias / table models
    {% do summary_report.append('') %}
    {% do summary_report.append("### table names (alias) and related models") %}
    {% for al in alias_to_cols|sort %}
        {% do summary_report.append('') %}
        {% do summary_report.append("- " ~ al ~ ' :') %}
        {% for model in all_models %}
            {% if model.alias == al %}
                {% do summary_report.append("  - " ~ model.name ) %}
            {% endif %}
        {% endfor %}
    {% endfor %}

{% if execute %}

    {% set joined = summary_report | join ('\n') %}
    {{ log(joined, info=True) }}
    {% do return(joined) %}

{% endif %}

{% endmacro %}