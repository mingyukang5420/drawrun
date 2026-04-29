package com.running.app.domain.track.entity;

import com.running.app.domain.common.BaseRDBEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.MultiLineString;

@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(name = "tracks")
public class Track extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "track_id")
    private Long trackId;

    // 4326 : GPS 위경도 좌표계 SRID
    @Column(
            name = "geom",
            nullable = false,
            columnDefinition = "geometry(MultiLineString, 4326)"
    )
    private MultiLineString geom;

    @Column(
            name = "distance",
            nullable = false
    )
    private Double distance;

    @Column(
            name = "track_image_url",
            nullable = false,
            length = 500
    )
    private String trackImageUrl;
}
