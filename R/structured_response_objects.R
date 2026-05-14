structured_response_objects <- list(
  # ---- Simple politics response format
  tar_target(
    name = structured_response_format_politics_simple,
    command = ellmer::type_object(
        about_politics = ellmer::type_boolean(), 
        justification = ellmer::type_string(), 
        confidence_score = ellmer::type_number()
    ),
    description = "Prompts: Structured response format object for simple politics prompt"
  ),
  # ---- Themes response format
  tar_target(
    name = structured_response_format_politics_themes,
    command = ellmer::type_object(
      themes = ellmer::type_array(
        ellmer::type_enum(unique(stats::na.omit(politics_categories$category))),
        description = "Return between 1 and 4 themes from the provided categories."
      )
    ),
    description = "Prompts: Structured response format object for politics themes prompt"
  )
)
