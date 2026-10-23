CLASS zcl_hcm_generate_mock_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_hcm_generate_mock_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA: lt_job_offers TYPE STANDARD TABLE OF zhcm_joboffer,
          lt_pipe_steps TYPE STANDARD TABLE OF zhcm_pipe_tmpl.

    TRY.
      GET TIME STAMP FIELD DATA(lv_ts).

      " Clear existing data
      DELETE FROM zhcm_joboffer.
      DELETE FROM zhcm_pipe_tmpl.
      DELETE FROM zhcm_pipe_prog.
      DELETE FROM zhcm_applicatn.
      DELETE FROM zhcm_candidate.

      DELETE FROM zhcm_explvl.
      DELETE FROM zhcm_conttyp.
      DELETE FROM zhcm_jobstat.
      DELETE FROM zhcm_orgunit.
      DELETE FROM zhcm_step_type.

      " Populate Value Helps
      INSERT zhcm_explvl FROM TABLE @( VALUE #(
        ( client = sy-mandt exp_level = 'Entry Level' description = '0-2 years' )
        ( client = sy-mandt exp_level = 'Mid Level' description = '3-5 years' )
        ( client = sy-mandt exp_level = 'Senior Level' description = '5+ years' )
        ( client = sy-mandt exp_level = 'Lead / Manager' description = 'Leadership' )
      ) ).

      INSERT zhcm_conttyp FROM TABLE @( VALUE #(
        ( client = sy-mandt contract_type = 'Full-time' description = 'Permanent Full-Time' )
        ( client = sy-mandt contract_type = 'Part-time' description = 'Permanent Part-Time' )
        ( client = sy-mandt contract_type = 'Contract' description = 'Fixed-term Contract' )
        ( client = sy-mandt contract_type = 'Freelance' description = 'Freelancer / External' )
        ( client = sy-mandt contract_type = 'Internship' description = 'Intern / Trainee' )
      ) ).

      INSERT zhcm_jobstat FROM TABLE @( VALUE #(
        ( client = sy-mandt status = 'D' description = 'Draft' )
        ( client = sy-mandt status = 'P' description = 'Published' )
        ( client = sy-mandt status = 'C' description = 'Closed' )
      ) ).

      INSERT zhcm_step_type FROM TABLE @( VALUE #(
        ( client = sy-mandt step_type = 'SCREEN' description = 'AI / HR Screening' )
        ( client = sy-mandt step_type = 'INTERV' description = 'Interview' )
        ( client = sy-mandt step_type = 'TECH' description = 'Technical Test' )
        ( client = sy-mandt step_type = 'OFFER' description = 'Offer Stage' )
        ( client = sy-mandt step_type = 'BGC' description = 'Background Check' )
      ) ).

      " Populate 10 Departments
      DATA: lt_depts TYPE STANDARD TABLE OF zhcm_orgunit.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Engineering' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Product Management' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Design' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Data Science' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Marketing' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Sales' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Customer Success' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Human Resources' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Finance' status = 'A' ) TO lt_depts.
      APPEND VALUE #( org_unit_id = cl_system_uuid=>create_uuid_x16_static( ) unit_name = 'Legal' status = 'A' ) TO lt_depts.
      INSERT zhcm_orgunit FROM TABLE @lt_depts.

      " Offer 1: Senior Backend Engineer
      DATA(lv_offer1_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer1_id
        title = 'Senior Backend Engineer'
        description = 'Join our Engineering team. We are looking for highly motivated individuals.'
        department = 'Engineering'
        required_skills = 'Node.js, PostgreSQL, AWS'
        experience_level = 'Senior Level'
        contract_type = 'Full-time'
        location = 'Remote'
        positions_needed = 2
        positions_filled = 0
        salary_min = 130000
        salary_max = 170000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer1_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 2: Frontend React Developer
      DATA(lv_offer2_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer2_id
        title = 'Frontend React Developer'
        description = 'Join our Engineering team. We are looking for highly motivated individuals.'
        department = 'Engineering'
        required_skills = 'React, Redux, Tailwind'
        experience_level = 'Mid Level'
        contract_type = 'Full-time'
        location = 'New York, NY'
        positions_needed = 3
        positions_filled = 0
        salary_min = 110000
        salary_max = 140000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer2_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 3: DevOps Engineer
      DATA(lv_offer3_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer3_id
        title = 'DevOps Engineer'
        description = 'Join our Engineering team. We are looking for highly motivated individuals.'
        department = 'Engineering'
        required_skills = 'Kubernetes, Docker, CI/CD'
        experience_level = 'Senior Level'
        contract_type = 'Contract'
        location = 'London, UK'
        positions_needed = 1
        positions_filled = 0
        salary_min = 120000
        salary_max = 160000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer3_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer3_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer3_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer3_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer3_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 4: VP of Product
      DATA(lv_offer4_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer4_id
        title = 'VP of Product'
        description = 'Join our Product Management team. We are looking for highly motivated individuals.'
        department = 'Product Management'
        required_skills = 'Product Strategy, Leadership, Agile'
        experience_level = 'Lead / Manager'
        contract_type = 'Full-time'
        location = 'San Francisco, CA'
        positions_needed = 1
        positions_filled = 0
        salary_min = 180000
        salary_max = 250000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer4_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer4_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer4_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer4_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer4_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 5: Product Manager
      DATA(lv_offer5_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer5_id
        title = 'Product Manager'
        description = 'Join our Product Management team. We are looking for highly motivated individuals.'
        department = 'Product Management'
        required_skills = 'Jira, Roadmap Planning, UX'
        experience_level = 'Mid Level'
        contract_type = 'Full-time'
        location = 'Remote'
        positions_needed = 2
        positions_filled = 0
        salary_min = 120000
        salary_max = 150000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer5_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer5_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer5_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer5_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer5_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 6: Senior UX Designer
      DATA(lv_offer6_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer6_id
        title = 'Senior UX Designer'
        description = 'Join our Design team. We are looking for highly motivated individuals.'
        department = 'Design'
        required_skills = 'Figma, User Research, Prototyping'
        experience_level = 'Senior Level'
        contract_type = 'Full-time'
        location = 'Berlin, Germany'
        positions_needed = 2
        positions_filled = 0
        salary_min = 100000
        salary_max = 130000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer6_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer6_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer6_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer6_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer6_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 7: UI/Visual Designer
      DATA(lv_offer7_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer7_id
        title = 'UI/Visual Designer'
        description = 'Join our Design team. We are looking for highly motivated individuals.'
        department = 'Design'
        required_skills = 'Adobe CC, Figma, Animation'
        experience_level = 'Entry Level'
        contract_type = 'Freelance'
        location = 'Remote'
        positions_needed = 1
        positions_filled = 0
        salary_min = 60000
        salary_max = 90000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer7_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer7_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer7_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer7_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer7_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 8: Lead Data Scientist
      DATA(lv_offer8_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer8_id
        title = 'Lead Data Scientist'
        description = 'Join our Data Science team. We are looking for highly motivated individuals.'
        department = 'Data Science'
        required_skills = 'Python, Machine Learning, SQL'
        experience_level = 'Lead / Manager'
        contract_type = 'Full-time'
        location = 'Boston, MA'
        positions_needed = 2
        positions_filled = 0
        salary_min = 160000
        salary_max = 210000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer8_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer8_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer8_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer8_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer8_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 9: Data Analyst
      DATA(lv_offer9_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer9_id
        title = 'Data Analyst'
        description = 'Join our Data Science team. We are looking for highly motivated individuals.'
        department = 'Data Science'
        required_skills = 'SQL, Tableau, Excel'
        experience_level = 'Mid Level'
        contract_type = 'Full-time'
        location = 'Remote'
        positions_needed = 1
        positions_filled = 0
        salary_min = 90000
        salary_max = 120000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer9_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer9_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer9_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer9_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer9_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 10: Growth Marketing Manager
      DATA(lv_offer10_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer10_id
        title = 'Growth Marketing Manager'
        description = 'Join our Marketing team. We are looking for highly motivated individuals.'
        department = 'Marketing'
        required_skills = 'SEO, SEM, Analytics'
        experience_level = 'Mid Level'
        contract_type = 'Full-time'
        location = 'Austin, TX'
        positions_needed = 2
        positions_filled = 0
        salary_min = 95000
        salary_max = 125000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer10_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer10_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer10_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer10_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer10_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 11: Content Writer
      DATA(lv_offer11_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer11_id
        title = 'Content Writer'
        description = 'Join our Marketing team. We are looking for highly motivated individuals.'
        department = 'Marketing'
        required_skills = 'Copywriting, SEO, Blogging'
        experience_level = 'Entry Level'
        contract_type = 'Part-time'
        location = 'Remote'
        positions_needed = 2
        positions_filled = 0
        salary_min = 50000
        salary_max = 70000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer11_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer11_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer11_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer11_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer11_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 12: Enterprise Account Executive
      DATA(lv_offer12_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer12_id
        title = 'Enterprise Account Executive'
        description = 'Join our Sales team. We are looking for highly motivated individuals.'
        department = 'Sales'
        required_skills = 'B2B Sales, Salesforce, Negotiation'
        experience_level = 'Senior Level'
        contract_type = 'Full-time'
        location = 'Chicago, IL'
        positions_needed = 2
        positions_filled = 0
        salary_min = 110000
        salary_max = 150000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer12_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer12_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer12_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer12_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer12_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 13: Customer Success Manager
      DATA(lv_offer13_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer13_id
        title = 'Customer Success Manager'
        description = 'Join our Customer Success team. We are looking for highly motivated individuals.'
        department = 'Customer Success'
        required_skills = 'CRM, Communication, Retention'
        experience_level = 'Mid Level'
        contract_type = 'Full-time'
        location = 'Remote'
        positions_needed = 1
        positions_filled = 0
        salary_min = 85000
        salary_max = 110000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer13_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer13_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer13_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer13_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer13_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 14: HR Business Partner
      DATA(lv_offer14_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer14_id
        title = 'HR Business Partner'
        description = 'Join our Human Resources team. We are looking for highly motivated individuals.'
        department = 'Human Resources'
        required_skills = 'Employee Relations, Recruiting'
        experience_level = 'Senior Level'
        contract_type = 'Full-time'
        location = 'Seattle, WA'
        positions_needed = 3
        positions_filled = 0
        salary_min = 100000
        salary_max = 135000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer14_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer14_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer14_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer14_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer14_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Offer 15: Corporate Counsel
      DATA(lv_offer15_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        offer_id = lv_offer15_id
        title = 'Corporate Counsel'
        description = 'Join our Legal team. We are looking for highly motivated individuals.'
        department = 'Legal'
        required_skills = 'Contract Law, Compliance, IP'
        experience_level = 'Lead / Manager'
        contract_type = 'Full-time'
        location = 'Remote'
        positions_needed = 1
        positions_filled = 0
        salary_min = 150000
        salary_max = 200000
        currency_code = 'USD'
        status = 'P'
        valid_until = '20261231'
        created_at = lv_ts
        local_last_changed_at = lv_ts
      ) TO lt_job_offers.

      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer15_id step_name = 'Initial Screening' step_order = 1 step_type = 'SCREEN' step_desc = 'Resume and profile review.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer15_id step_name = 'HR Interview' step_order = 2 step_type = 'INTERV' step_desc = 'Cultural fit and expectations.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer15_id step_name = 'Technical Assessment' step_order = 3 step_type = 'TECH' step_desc = 'Skills evaluation.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer15_id step_name = 'Manager Interview' step_order = 4 step_type = 'INTERV' step_desc = 'Deep dive with the hiring manager.' ) TO lt_pipe_steps.
      APPEND VALUE #( template_id = cl_system_uuid=>create_uuid_x16_static( ) offer_id = lv_offer15_id step_name = 'Final Offer' step_order = 5 step_type = 'OFFER' step_desc = 'Negotiation and formal offer.' ) TO lt_pipe_steps.

      " Save to Database
      INSERT zhcm_joboffer FROM TABLE @lt_job_offers.
      INSERT zhcm_pipe_tmpl FROM TABLE @lt_pipe_steps.

      COMMIT WORK.
      out->write( 'Mock data generated successfully!' ).
      out->write( |Inserted { lines( lt_job_offers ) } Job Offers and { lines( lt_pipe_steps ) } Pipeline Steps.| ).

    CATCH cx_uuid_error INTO DATA(lx_uuid).
      out->write( 'Error generating UUID' ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.

