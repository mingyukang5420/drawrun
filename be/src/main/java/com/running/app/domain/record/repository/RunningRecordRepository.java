package com.running.app.domain.record.repository;

import com.running.app.domain.record.entity.RunningRecord;
import org.springframework.data.jpa.repository.JpaRepository;

//우선은 기본 JpsRepository로 생성
public interface RunningRecordRepository extends JpaRepository<RunningRecord, Long> {

}
