package com.a103.webhookBridge.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record JenkinsRequest(
        @NotBlank
        String status,  // STARTED / SUCCESS / UNSTABLE / FAILURE

        @JsonProperty("job_name")
        @NotBlank
        String jobName,

        @JsonProperty("build_number")
        @NotNull
        Integer buildNumber,

        @JsonProperty("build_url")
        String buildUrl,

        @JsonProperty("start_time")
        String startTime,

        @JsonProperty("end_time")
        String endTime,

        String duration,

        @Valid
        MergeRequestInfo mr,

        @Valid
        CommitInfo commit,

        @JsonProperty("test_summary")
        TestSummary testSummary
) {

    public record MergeRequestInfo(
            String iid,
            String title,
            String url,
            String author,
            String username,
            String source,
            String target
    ) {

        public boolean isMrTriggered() {
            return iid != null && !iid.isBlank();
        }
    }

    public record CommitInfo(
            @JsonProperty("short") String shortHash,
            @JsonProperty("full") String fullHash
    ) {

    }

    public record TestSummary(
            Integer passed,
            Integer failed,
            Integer skipped,
            Integer total,
            @JsonProperty("new_failures") Integer newFailures
    ) {

        public boolean hasTests() {
            return total != null && total > 0;
        }
    }
}