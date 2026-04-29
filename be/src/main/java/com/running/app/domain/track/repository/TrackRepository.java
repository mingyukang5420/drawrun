package com.running.app.domain.track.repository;

import com.running.app.domain.track.entity.Track;
import org.springframework.data.jpa.repository.JpaRepository;

//우선은 기본 JpsRepository로 생성
public interface TrackRepository extends JpaRepository<Track, Long> {
}
