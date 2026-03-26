with source as (
    select * from {{ source('coseller_airbyte', 'contacts') }}
),

renamed as (
    select
        _id                                                     as id,
        "firstName"                                             as first_name,
        "lastName"                                              as last_name,
        "middleName"                                            as middle_name,
        title,
        email,
        "directPhone"                                           as direct_phone,
        mobile,
        city,
        "completeAddress"                                       as complete_address,
        zipcode,
        "linkedinUrl" #>>'{}'                                    as linkedin_url,
        remarks,
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
        modified->'by'->>'name'                                 as modified_by_name

    from source
    where "_ab_cdc_deleted_at" is null
)

select * from renamed
