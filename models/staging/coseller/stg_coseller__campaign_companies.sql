with source as (
    select * from {{ source('coseller_airbyte', 'campaign_companies') }}
),

renamed as (
    select
        _id                                                     as id,
        active::boolean                                         as active,
        "campaignId"                                            as campaign_id,
        "companyId"                                             as company_id,
        "importedName"                                          as imported_name,
        status,
        "leadStatus"                                            as lead_status,
        category,
        validated::boolean                                      as validated,
        remarks,
        "listName"                                              as list_name,
        "instanceId"                                            as instance_id,
        fields,

        -- embedded prio (jsonb array → text array)
        prio,

        -- embedded assignedTo
        "assignedTo"->>'_id'                                    as assigned_to_id,
        "assignedTo"->>'name'                                   as assigned_to_name,

        -- embedded lastUser
        "lastUser"->>'_id'                                      as last_user_id,
        "lastUser"->>'name'                                     as last_user_name,

        -- contactedOn (varchar timestamp)
        "contactedOn"::timestamp                                as contacted_on,

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

-- filter orphaned company references (5,263 rows / 0.42% of total)
valid_refs as (
    select r.*
    from renamed r
    where exists (
        select 1 from {{ source('coseller_airbyte', 'companies') }} c
        where c._id = r.company_id
    )
)

select * from valid_refs
