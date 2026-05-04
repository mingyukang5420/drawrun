package com.running.app.global.osm.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.Point;

@Entity
@Table(name = "osm_crossings")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OsmCrossing {

    @Id
    @Column(name = "osm_id", nullable = false, unique = true)
    private Long osmId;

    @Column(name = "crossing", length = 30)
    private String crossing;

    @Column(name = "has_signals")
    private Boolean hasSignals = false;

    @Column(name = "geom", nullable = false, columnDefinition = "geometry(Point, 4326)")
    private Point geom;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

}