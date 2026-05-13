package com.running.app.domain.track.service;

import com.running.app.domain.track.dto.TrackRequest;
import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Path2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.List;
import javax.imageio.ImageIO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class TrackRouteRenderService {

    private static final int IMAGE_WIDTH = 1024;
    private static final int IMAGE_HEIGHT = 1024;
    private static final int PADDING = 96;
    private static final int START_END_MARKER_SIZE = 18;
    private static final float ROUTE_STROKE_WIDTH = 14f;
    private static final DateTimeFormatter FILE_TIME_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");

    public Path renderRouteToDesktop(List<TrackRequest.NodeDTO> nodes, String title) {
        return renderRouteImageToDesktop(nodes, title).outputPath();
    }

    public RenderedRouteImage renderRouteImageToDesktop(List<TrackRequest.NodeDTO> nodes, String title) {
        if (nodes == null || nodes.size() < 2) {
            throw new IllegalArgumentException("At least two nodes are required to render a route image.");
        }

        BufferedImage image = new BufferedImage(IMAGE_WIDTH, IMAGE_HEIGHT, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = image.createGraphics();

        try {
            configureGraphics(graphics);
            paintBackground(graphics);

            Bounds bounds = calculateBounds(nodes);
            RenderScale renderScale = calculateRenderScale(bounds);
            Path2D routePath = buildRoutePath(nodes, bounds, renderScale);

            graphics.setColor(new Color(30, 64, 175));
            graphics.setStroke(new BasicStroke(
                    ROUTE_STROKE_WIDTH,
                    BasicStroke.CAP_ROUND,
                    BasicStroke.JOIN_ROUND
            ));
            graphics.draw(routePath);

            drawStartAndEndMarkers(graphics, nodes, bounds, renderScale);

            byte[] pngBytes = toPngBytes(image);
            Path outputPath = createDesktopOutputPath(title);
            Files.write(outputPath, pngBytes);
            log.info("Rendered route PNG saved to {}", outputPath);
            return new RenderedRouteImage(
                    outputPath,
                    pngBytes,
                    Base64.getEncoder().encodeToString(pngBytes)
            );
        } catch (IOException e) {
            throw new IllegalStateException("Failed to save rendered route image.", e);
        } finally {
            graphics.dispose();
        }
    }

    private void configureGraphics(Graphics2D graphics) {
        graphics.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        graphics.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
        graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
    }

    private void paintBackground(Graphics2D graphics) {
        graphics.setColor(Color.WHITE);
        graphics.fillRect(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    }

    private Bounds calculateBounds(List<TrackRequest.NodeDTO> nodes) {
        double minLat = Double.MAX_VALUE;
        double maxLat = -Double.MAX_VALUE;
        double minLng = Double.MAX_VALUE;
        double maxLng = -Double.MAX_VALUE;

        for (TrackRequest.NodeDTO node : nodes) {
            minLat = Math.min(minLat, node.getLat());
            maxLat = Math.max(maxLat, node.getLat());
            minLng = Math.min(minLng, node.getLng());
            maxLng = Math.max(maxLng, node.getLng());
        }

        return new Bounds(minLat, maxLat, minLng, maxLng);
    }

    private RenderScale calculateRenderScale(Bounds bounds) {
        double latRange = Math.max(bounds.maxLat - bounds.minLat, 1e-9);
        double lngRange = Math.max(bounds.maxLng - bounds.minLng, 1e-9);

        double drawableWidth = IMAGE_WIDTH - (PADDING * 2.0);
        double drawableHeight = IMAGE_HEIGHT - (PADDING * 2.0);

        double scale = Math.min(drawableWidth / lngRange, drawableHeight / latRange);
        double routeWidth = lngRange * scale;
        double routeHeight = latRange * scale;

        double offsetX = (IMAGE_WIDTH - routeWidth) / 2.0;
        double offsetY = (IMAGE_HEIGHT - routeHeight) / 2.0;

        return new RenderScale(scale, offsetX, offsetY);
    }

    private Path2D buildRoutePath(
            List<TrackRequest.NodeDTO> nodes,
            Bounds bounds,
            RenderScale renderScale
    ) {
        Path2D path = new Path2D.Double();

        for (int index = 0; index < nodes.size(); index++) {
            TrackRequest.NodeDTO node = nodes.get(index);
            Point point = toPoint(node, bounds, renderScale);

            if (index == 0) {
                path.moveTo(point.x, point.y);
            } else {
                path.lineTo(point.x, point.y);
            }
        }

        return path;
    }

    private void drawStartAndEndMarkers(
            Graphics2D graphics,
            List<TrackRequest.NodeDTO> nodes,
            Bounds bounds,
            RenderScale renderScale
    ) {
        Point startPoint = toPoint(nodes.get(0), bounds, renderScale);
        Point endPoint = toPoint(nodes.get(nodes.size() - 1), bounds, renderScale);

        graphics.setColor(new Color(22, 163, 74));
        graphics.fillOval(
                (int) Math.round(startPoint.x) - START_END_MARKER_SIZE / 2,
                (int) Math.round(startPoint.y) - START_END_MARKER_SIZE / 2,
                START_END_MARKER_SIZE,
                START_END_MARKER_SIZE
        );

        graphics.setColor(new Color(220, 38, 38));
        graphics.fillOval(
                (int) Math.round(endPoint.x) - START_END_MARKER_SIZE / 2,
                (int) Math.round(endPoint.y) - START_END_MARKER_SIZE / 2,
                START_END_MARKER_SIZE,
                START_END_MARKER_SIZE
        );
    }

    private Point toPoint(TrackRequest.NodeDTO node, Bounds bounds, RenderScale renderScale) {
        double x = renderScale.offsetX + ((node.getLng() - bounds.minLng) * renderScale.scale);
        double y = renderScale.offsetY + ((bounds.maxLat - node.getLat()) * renderScale.scale);
        return new Point(x, y);
    }

    private byte[] toPngBytes(BufferedImage image) throws IOException {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        ImageIO.write(image, "png", outputStream);
        return outputStream.toByteArray();
    }

    private Path createDesktopOutputPath(String title) throws IOException {
        Path desktopPath = Paths.get(System.getProperty("user.home"), "Desktop");
        Files.createDirectories(desktopPath);

        String safeTitle = sanitizeFileName(title);
        String timestamp = LocalDateTime.now().format(FILE_TIME_FORMAT);
        return desktopPath.resolve("route-" + safeTitle + "-" + timestamp + ".png");
    }

    private String sanitizeFileName(String title) {
        if (title == null || title.isBlank()) {
            return "untitled";
        }

        String sanitized = title.replaceAll("[^a-zA-Z0-9-_]", "_");
        return sanitized.length() > 40 ? sanitized.substring(0, 40) : sanitized;
    }

    private record Bounds(double minLat, double maxLat, double minLng, double maxLng) {
    }

    private record RenderScale(double scale, double offsetX, double offsetY) {
    }

    private record Point(double x, double y) {
    }

    public record RenderedRouteImage(
            Path outputPath,
            byte[] pngBytes,
            String base64Png
    ) {
    }
}
