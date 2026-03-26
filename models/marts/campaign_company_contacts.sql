{{
    config(
        indexes=[
            {'columns': ['campaign_id'], 'type': 'btree'},
            {'columns': ['company_id'], 'type': 'btree'},
            {'columns': ['contact_id'], 'type': 'btree'},
            {'columns': ['instance_id'], 'type': 'btree'},
            {'columns': ['campaign_id', 'company_id'], 'type': 'btree'},
            {'columns': ['company_id', 'contact_id'], 'type': 'btree'},
        ]
    )
}}

select
    id,
    campaign_id,
    company_id,
    contact_id,
    status,
    active,
    has_remarks,
    in_list,
    role,
    rank,
    call_attempts,
    instance_id,
    fields,
    prio,
    last_user_id,
    last_user_name,
    created_at,
    created_by_id,
    created_by_name,
    modified_at,
    modified_by_id,
    modified_by_name
from {{ ref('stg_coseller__campaign_company_contacts') }}
