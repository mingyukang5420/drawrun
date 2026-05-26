package com.running.app.domain.course.service;

import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.track.entity.Track;
import com.running.app.global.osm.repository.OsmWayRepository;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class DifficultyService {

    private static final double EARTH_RADIUS_KM = 6371.0;

    private final OsmWayRepository osmWayRepository;

    public CourseDifficulty calculate(Track track) {
        Coordinate[] coords = track.getGeom().getCoordinates();

        double[] elevations = fetchElevations(coords);
        double totalDistanceKm = calculateTotalDistance(coords);
        double avgUphillSlope = calculateAvgUphillSlope(coords, elevations);
        double totalElevationGain = calculateTotalElevationGain(elevations);

        return determineDifficulty(totalDistanceKm, avgUphillSlope, totalElevationGain);
    }

    private CourseDifficulty determineDifficulty(double distanceKm, double avgUphillSlopePct, double totalElevationGainM) {
        CourseDifficulty byDistance = distanceKm < 3.0 ? CourseDifficulty.BEGINNER
                : distanceKm < 5.0 ? CourseDifficulty.EASY
                : distanceKm < 8.0 ? CourseDifficulty.NORMAL
                : CourseDifficulty.HARD;

        CourseDifficulty bySlope = avgUphillSlopePct < 2.0 ? CourseDifficulty.BEGINNER
                : avgUphillSlopePct < 4.0 ? CourseDifficulty.EASY
                : avgUphillSlopePct < 6.0 ? CourseDifficulty.NORMAL
                : CourseDifficulty.HARD;

        CourseDifficulty byElevationGain = totalElevationGainM < 30.0 ? CourseDifficulty.BEGINNER
                : totalElevationGainM < 60.0 ? CourseDifficulty.EASY
                : totalElevationGainM < 100.0 ? CourseDifficulty.NORMAL
                : CourseDifficulty.HARD;

        return maxDifficulty(byDistance, bySlope, byElevationGain);
    }

    private double[] fetchElevations(Coordinate[] coords) {
        double[] elevations = new double[coords.length];
        for (int i = 0; i < coords.length; i++) {
            Double elevation = osmWayRepository.findNearestNodeElevation(coords[i].x, coords[i].y);
            elevations[i] = elevation != null ? elevation : 0.0;
        }
        return elevations;
    }

    private double calculateTotalDistance(Coordinate[] coords) {
        double total = 0.0;
        for (int i = 0; i < coords.length - 1; i++) {
            total += haversineKm(coords[i], coords[i + 1]);
        }
        return total;
    }

    private double calculateAvgUphillSlope(Coordinate[] coords, double[] elevations) {
        double totalSlope = 0.0;
        int uphillCount = 0;
        for (int i = 0; i < coords.length - 1; i++) {
            double elevDiff = elevations[i + 1] - elevations[i];
            if (elevDiff > 0) {
                double distM = haversineKm(coords[i], coords[i + 1]) * 1000;
                if (distM > 0) {
                    totalSlope += (elevDiff / distM) * 100;
                    uphillCount++;
                }
            }
        }
        return uphillCount > 0 ? totalSlope / uphillCount : 0.0;
    }

    private double calculateTotalElevationGain(double[] elevations) {
        double gain = 0.0;
        for (int i = 0; i < elevations.length - 1; i++) {
            double diff = elevations[i + 1] - elevations[i];
            if (diff > 0) {
                gain += diff;
            }
        }
        return gain;
    }

    private double haversineKm(Coordinate c1, Coordinate c2) {
        double dLat = Math.toRadians(c2.y - c1.y);
        double dLng = Math.toRadians(c2.x - c1.x);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(c1.y)) * Math.cos(Math.toRadians(c2.y))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private CourseDifficulty maxDifficulty(CourseDifficulty a, CourseDifficulty b, CourseDifficulty c) {
        CourseDifficulty max = a;
        if (b.getWeight() > max.getWeight()) max = b;
        if (c.getWeight() > max.getWeight()) max = c;
        return max;
    }
}
