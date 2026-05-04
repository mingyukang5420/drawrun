package com.running.app.global.osm.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.LineString;

@Entity
@Table(name = "osm_ways_split")
@Getter
@NoArgsConstructor
public class OsmSplit {

    @Id
    @Column(name = "id")
    private Long splitId;

    @ManyToOne
    @JoinColumn(name = "source_osm_id")
    private OsmWay osmWay;

    @Column(name = "geom", nullable = false, columnDefinition = "geometry(LineString, 4326)")
    private LineString geom;
}
