{{
    config(
        indexes=[
            {'columns': ['instance_id'], 'type': 'btree'},
            {'columns': ['org_no'], 'type': 'btree'},
            {'columns': ['active'], 'type': 'btree'},
        ]
    )
}}

select
    id,
    name,
    org_no,
    active,
    validated,
    site,
    linkedin_url,
    telephone,
    telefax,
    zipcode,
    box_address,
    street_address,
    city,
    municipality,
    county,
    year_established,
    parent_company,
    currency,
    global_remarks,
    campaign_remarks,
    bv_source,
    instance_id,
    country_id,
    country_name,
    created_at,
    created_by_id,
    created_by_name,
    modified_at,
    modified_by_id,
    modified_by_name,
    activities,
    fiscal
from {{ ref('stg_coseller__companies') }}
