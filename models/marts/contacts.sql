{{
    config(
        indexes=[
            {'columns': ['instance_id'], 'type': 'btree'},
            {'columns': ['email'], 'type': 'btree'},
            {'columns': ['first_name'], 'type': 'btree'},
            {'columns': ['last_name'], 'type': 'btree'},
        ]
    )
}}

select
    id,
    first_name,
    middle_name,
    last_name,
    title,
    email,
    direct_phone,
    mobile,
    city,
    complete_address,
    zipcode,
    linkedin_url,
    remarks,
    instance_id,
    country_id,
    country_name,
    created_at,
    created_by_id,
    created_by_name,
    modified_at,
    modified_by_id,
    modified_by_name
from {{ ref('stg_coseller__contacts') }}
