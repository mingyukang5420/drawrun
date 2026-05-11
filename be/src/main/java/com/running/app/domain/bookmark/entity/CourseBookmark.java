package com.running.app.domain.bookmark.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.course.entity.Course;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(
        name = "course_bookmark",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_course_bookmark_member_course",
                        columnNames = {"member_id", "course_id"}
                )
        }
)
public class CourseBookmark extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "course_bookmark_id")
    private Long id;

    @Column(name = "member_id", nullable = false)
    private Long memberId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;
}
