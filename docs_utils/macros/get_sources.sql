{% macro get_sources() %}

    {% set all_sources_list  = [] %}
    {% for source in graph.sources.values() %}
        {% do all_sources_list.append(source) %}
    {% endfor %}
    
    {% set source_relations = [] %}
    {% for src in all_sources_list %}
        {% do source_relations.append(src.get('relation_name')) %}
    {% endfor %}

{% if execute %}
    {{ log(source_relations, info=True) }}
    {% do return(all_sources_list) %}
{% endif %}

{% endmacro %}