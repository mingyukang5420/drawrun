package com.running.app.domain.example.controller;

import com.running.app.domain.example.dto.ExampleRequest;
import com.running.app.domain.example.dto.ExampleResponse;
import com.running.app.domain.example.dto.ExampleResponse.exampleResponseDTO;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/example/test")
@Tag(name = "ExampleController 입니다", description = "Swagger 예시를 위한 example")
public class ExampleController {

    @GetMapping("/testGet")
    @Operation(
            summary = "Get 요청을 test 하기 위함",
            description = """
                    해당 페이지는 Swagger 테스틑 위해서 막 작성한
                    swagger의 예시가 될 수 있는
                    <br/>
                    - 클릭시 아무것도 동작하지
                    - 않습니다.
                    """
    )
    @Parameter(description = "name",
            example = "Park Seongmoon",
            required = true
    )
    public void testGet(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "테스트로 입력했습니다",
                    required = true
            )
            @RequestBody int dto
    ) {
        return;
    }

    @PostMapping("/testPost")
    @Operation(
            summary = "Post 요청을 test 하기 위함",
            description = """
                    해당 페이지는 Swagger 테스틑 위해서 막 작성한
                    swagger의 예시가 될 수 있는
                    <br/>
                    - 클릭시 아무것도 동작하지
                    - 않습니다.
                    """
    )
    public ApiResponse<exampleResponseDTO> testPost(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "@RequestBody를 위한 요청 데이터",
                    required = true,
                    content = @Content(
                            mediaType = "application/json",
                            schema = @Schema(implementation = ExampleRequest.exampleRequestDTO.class)
                    )
            )
            @RequestBody ExampleRequest.exampleRequestDTO requestDTO
    ) {
        ExampleResponse.exampleResponseDTO response = ExampleResponse.exampleResponseDTO.builder()
                .message("성공")
                .data("전달받은 메시지: " + requestDTO.getMessage())
                .timestamp(LocalDateTime.now())
                .build();

        return ApiResponse.onSuccess(response);
    }
}
