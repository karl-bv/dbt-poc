{{
    config(
        indexes=[
            {'columns': ['campaign_id'], 'type': 'btree'},
            {'columns': ['company_id'], 'type': 'btree'},
            {'columns': ['instance_id'], 'type': 'btree'},
            {'columns': ['active'], 'type': 'btree'},
            {'columns': ['status'], 'type': 'btree'},
            {'columns': ['lead_status'], 'type': 'btree'},
        ]
    )
}}

select
    id,
    active,
    campaign_id,
    company_id,
    imported_name,
    prio,
    status,
    lead_status,
    category,
    validated,
    remarks,
    list_name,
    instance_id,
    fields,
    assigned_to_id,
    assigned_to_name,
    last_user_id,
    last_user_name,
    contacted_on,
    created_at,
    created_by_id,
    created_by_name,
    modified_at,
    modified_by_id,
    modified_by_name
from {{ ref('stg_coseller__campaign_companies') }}
