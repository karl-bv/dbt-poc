with source as (
    select * from {{ source('coseller_airbyte', 'campaign_company_contacts') }}
),

renamed as (
    select
        _id                                                     as id,
        "campaignId" #>>'{}'                                     as campaign_id,
        "companyId"                                             as company_id,
        "contactId"                                             as contact_id,
        status,
        active::boolean                                         as active,
        "hasRemarks"::boolean                                   as has_remarks,
        "inList"::boolean                                       as in_list,
        role,
        rank,
        "callAttempts"::integer                                 as call_attempts,
        "instanceId"                                            as instance_id,
        fields,

        -- embedded prio (jsonb array)
        prio,

        -- embedded lastUser
        "lastUser"->>'_id'                                      as last_user_id,
        "lastUser"->>'name'                                     as last_user_name,

        -- embedded created
        (created->>'on')::timestamp                             as created_at,
        created->'by'->>'_id'                                   as created_by_id,
        created->'by'->>'name'                                  as created_by_name,

        -- embedded modified
        (modified->>'on')::timestamp                            as modified_at,
        modified->'by'->>'_id'                                  as modified_by_id,
        modified->'by'->>'name'                                 as modified_by_name

    from source
    where "_ab_cdc_deleted_at" is null
),

-- filter orphaned references:
-- company_id not in companies: 7,684 rows (0.39%)
-- contact_id not in contacts: 219 rows (0.01%)
valid_refs as (
    select r.*
    from renamed r
    where exists (
        select 1 from {{ source('coseller_airbyte', 'companies') }} c
        where c._id = r.company_id
    )
    and exists (
        select 1 from {{ source('coseller_airbyte', 'contacts') }} ct
        where ct._id = r.contact_id
    )
)

select * from valid_refs
