package com.running.app.domain.coursedraft.type;

public enum CourseDraftFilterType {
    ALL,         // 전체 (상태·등록 여부 무관)
    READY,       // 작성중 (에디터 저장만, 아직 뛰지 않음)
    DONE,        // 검증됨 (뛰어봤으나 정식 등록 전 또는 등록 후)
    REGISTERED   // 등록됨 (courses 테이블에 행 존재)
}
