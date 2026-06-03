# frozen_string_literal: true

# name: discourse-animated-avatars-plus
# about: Adds support for animated avatars with group-based permission
# version: 0.2
# url: https://github.com/xhyeops/discourse-animated-avatars-plus

after_initialize do
  require_relative "lib/discourse_animated_avatars/upload_creator_gifsicle_extension"
  require_relative "lib/discourse_animated_avatars/upload_creator_no_gifsicle_extension"
  require_relative "lib/discourse_animated_avatars/optimized_image_extension"
  require_relative "lib/discourse_animated_avatars/user_avatars_controller_extension"

  reloadable_patch do
    gifsicle_installed =
      begin
        Discourse::Utils.execute_command(
          "gifsicle",
          "--version",
          "&>",
          "/dev/null",
          failure_message: "gifsicle not found",
        )
        true
      rescue StandardError
        false
      end

    if gifsicle_installed
      UploadCreator.prepend(DiscourseAnimatedAvatars::UploadCreatorGifsicleExtension)
    else
      UploadCreator.prepend(DiscourseAnimatedAvatars::UploadCreatorNoGifsicleExtension)
    end

    OptimizedImage.prepend(DiscourseAnimatedAvatars::OptimizedImageExtension)
    UserAvatarsController.prepend(DiscourseAnimatedAvatars::UserAvatarsControllerExtension)
  end

  add_to_class(:user, :can_use_animated_avatar?) do
    allowed_groups =
      SiteSetting.animated_avatars_allowed_groups
        .to_s
        .split(/[|,]/)
        .map(&:strip)
        .reject(&:blank?)

    return false if allowed_groups.empty?

    groups.where(name: allowed_groups).exists?
  rescue StandardError
    false
  end

  add_to_class(:user, :animated_avatar) do
    return nil unless uploaded_avatar&.animated?
    return nil unless can_use_animated_avatar?

    uploaded_avatar.url
  rescue StandardError
    nil
  end

  add_to_serializer(:basic_user, :animated_avatar) do
    user.try(:animated_avatar)
  rescue StandardError
    nil
  end

  add_to_serializer(:post, :animated_avatar) do
    object.user.try(:animated_avatar)
  rescue StandardError
    nil
  end
end

Discourse::Application.routes.append do
  get "user_avatar/:hostname/:username/:size/:version.gif" => "user_avatars#show",
      :constraints => {
        hostname: /[\w\.-]+/,
        size: /\d+/,
        username: RouteFormat.username,
        format: :gif,
      }
end
