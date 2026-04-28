package com.running.app.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.LineString;

@Entity
@Table(name = "osm_ways", indexes = {
        @Index(name = "idx_osm_ways_highway", columnList = "highway")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OsmWay {

    @Id
    private Long id;

    @Column(name = "osm_id", nullable = false, unique = true)
    private Long osmId;

    @Column(name = "highway", nullable = false, length = 50)
    private String highway;

    @Column(name = "name", length = 255)
    private String name;

    @Column(name = "geom", nullable = false, columnDefinition = "geometry(LineString, 4326)")
    private LineString geom;

    @Column(name = "foot", length = 20)
    private String foot;

    @Column(name = "access", length = 20)
    private String access;

    @Column(name = "oneway", length = 10)
    private String oneway;

    @Column(name = "bridge")
    private Boolean bridge = false;

    @Column(name = "tunnel")
    private Boolean tunnel = false;

    @Column(name = "indoor")
    private Boolean indoor = false;

    @Column(name = "layer")
    private Short layer = 0;

    @Column(name = "surface", length = 30)
    private String surface;

    @Column(name = "lit")
    private Boolean lit;

    @Column(name = "sidewalk", length = 20)
    private String sidewalk;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

}
