package com.running.app.domain.district.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.locationtech.jts.geom.Polygon;

@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(name = "districts")
public class District {

    @Id
    @Column(name = "district_id", columnDefinition = "char(5)")
    private String id;

    @Column(name = "sido", nullable = false, length = 50)
    private String sido;

    @Column(name = "gu", nullable = false, length = 50)
    private String gu;

    @Column(name = "boundary", nullable = false, columnDefinition = "geometry(POLYGON, 4326)")
    private Polygon boundary;
}