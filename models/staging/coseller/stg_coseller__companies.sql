with source as (
    select * from {{ source('coseller_airbyte', 'companies') }}
),

renamed as (
    select
        _id                                                     as id,
        name,
        "orgNo"                                                 as org_no,
        active::boolean                                         as active,
        validated::boolean                                      as validated,
        site,
        "linkedInURL"                                           as linkedin_url,
        telephone,
        telefax,
        zipcode_1                                                as zipcode,
        "boxAddress"                                            as box_address,
        "streetAddress"                                         as street_address,
        city,
        municipality,
        county,
        "yearEstablished"                                       as year_established,
        "parentCompany"                                         as parent_company,
        currency,
        "globalRemarks"                                         as global_remarks,
        "campaignRemarks"                                       as campaign_remarks,
        bv_source,
        "instanceId"                                            as instance_id,

        -- embedded country
        country->>'_id'                                         as country_id,
        country->>'name'                                        as country_name,

        -- embedded created
        (created->>'on')::timestamp                             as created_at,
        created->'by'->>'_id'                                   as created_by_id,
        created->'by'->>'name'                                  as created_by_name,

        -- embedded modified
        (modified->>'on')::timestamp                            as modified_at,
        modified->'by'->>'_id'                                  as modified_by_id,
        modified->'by'->>'name'                                 as modified_by_name,

        -- keep arrays as jsonb for now
        activities,
        fiscal

    from source
    where "_ab_cdc_deleted_at" is null
)

select * from renamed
