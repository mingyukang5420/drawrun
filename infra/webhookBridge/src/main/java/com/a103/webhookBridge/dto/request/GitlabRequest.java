package com.a103.webhookBridge.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public record GitlabRequest(
        @JsonProperty("object_kind") String objectKind,
        @JsonProperty("before") String before,
        @JsonProperty("after") String after,
        @JsonProperty("user_username") String userUsername,
        @JsonProperty("user_name") String userName,
        @JsonProperty("user") User user,
        @JsonProperty("ref") String ref,
        @JsonProperty("project") Project project,
        @JsonProperty("object_attributes") MrAttributes attributes,
        @JsonProperty("labels") List<Label> labels,
        @JsonProperty("assignees") List<Assignee> assignees,
        @JsonProperty("commits") List<Commit> commits
) {

    public record Project(
            String name,
            @JsonProperty("web_url") String webUrl
    ) {

    }

    public record Label(
            String title
    ) {

    }

    public record Assignee(
            String name,
            String username
    ) {

    }

    public record MrAttributes(
            String title,
            String url,
            String state,
            String description,
            String action,
            @JsonProperty("source_branch") String sourceBranch,
            @JsonProperty("target_branch") String targetBranch,
            @JsonProperty("last_commit") LastCommit lastCommit
    ) {

    }

    public record LastCommit(
            String message
    ) {

    }

    public record Commit(
            String id,
            String message,
            String url,
            Author author
    ) {

    }

    public record Author(
            String name
    ) {

    }

    public record User(
            String name,
            String username
    ) {

    }
}
