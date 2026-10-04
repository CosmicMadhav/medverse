import 'package:flutter/material.dart';

enum RecordType { report, prescription, scan, discharge }

extension RecordTypeX on RecordType {
  String get label => switch (this) {
        RecordType.report => 'Lab Report',
        RecordType.prescription => 'Prescription',
        RecordType.scan => 'Scan',
        RecordType.discharge => 'Discharge Summary',
      };
  IconData get icon => switch (this) {
        RecordType.report => Icons.science_outlined,
        RecordType.prescription => Icons.medication_outlined,
        RecordType.scan => Icons.document_scanner_outlined,
        RecordType.discharge => Icons.local_hospital_outlined,
      };
}

class FamilyMember {
  final String id;
  final String name;
  final String relation;
  final int age;
  final String gender;
  final String bloodGroup;
  final Color color;
  final List<String> allergies;
  final List<String> conditions;
  final String emergencyContact;
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.color,
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContact = '',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  FamilyMember copyWith({
    String? name,
    String? relation,
    int? age,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContact,
  }) =>
      FamilyMember(
        id: id,
        name: name ?? this.name,
        relation: relation ?? this.relation,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        color: color,
        allergies: allergies ?? this.allergies,
        conditions: conditions ?? this.conditions,
        emergencyContact: emergencyContact ?? this.emergencyContact,
      );
}

enum ParamStatus { normal, low, high, critical }

class LabParam {
  final String name;
  final String value;
  final double numeric;
  final String unit;
  final double low;
  final double high;
  final ParamStatus status;
  final String simple;
  final String simpleHi;
  final String sourceLine;
  final double confidence;
  const LabParam({
    required this.name,
    required this.value,
    required this.numeric,
    required this.unit,
    required this.low,
    required this.high,
    required this.status,
    required this.simple,
    required this.simpleHi,
    required this.sourceLine,
    this.confidence = 0.97,
  });
}

class MedicalRecord {
  final String id;
  final String memberId;
  final String title;
  final RecordType type;
  final String hospital;
  final String doctor;
  final DateTime date;
  final String summary;
  final String summaryHi;
  final List<LabParam> params;
  final List<String> originalLines;
  final bool isPrivate;
  final List<String> tags;
  final List<String> imagePaths;
  final String note;
  final List<String> orderedTests;
  const MedicalRecord({
    required this.id,
    required this.memberId,
    required this.title,
    required this.type,
    required this.hospital,
    required this.doctor,
    required this.date,
    required this.summary,
    this.summaryHi = '',
    this.params = const [],
    this.originalLines = const [],
    this.isPrivate = false,
    this.tags = const [],
    this.imagePaths = const [],
    this.note = '',
    this.orderedTests = const [],
  });

  bool get hasCritical => params.any((p) => p.status == ParamStatus.critical);

  MedicalRecord copyWith({
    String? memberId,
    String? title,
    RecordType? type,
    String? hospital,
    String? doctor,
    DateTime? date,
    bool? isPrivate,
    List<String>? tags,
    String? note,
  }) =>
      MedicalRecord(
        id: id,
        memberId: memberId ?? this.memberId,
        title: title ?? this.title,
        type: type ?? this.type,
        hospital: hospital ?? this.hospital,
        doctor: doctor ?? this.doctor,
        date: date ?? this.date,
        summary: summary,
        summaryHi: summaryHi,
        params: params,
        originalLines: originalLines,
        isPrivate: isPrivate ?? this.isPrivate,
        tags: tags ?? this.tags,
        imagePaths: imagePaths,
        note: note ?? this.note,
        orderedTests: orderedTests,
      );
}

enum DiffTag { agree, differs, onlyA, onlyB }

class DiffPoint {
  final String topic;
  final DiffTag tag;
  final String doctorA;
  final String doctorB;
  final String plain;
  const DiffPoint({
    required this.topic,
    required this.tag,
    required this.doctorA,
    required this.doctorB,
    required this.plain,
  });
}

class OpinionCase {
  final String id;
  final String memberId;
  final String condition;
  final String? recordA;
  final String? recordB;
  final String doctorAName;
  final String doctorASpec;
  final String doctorAHospital;
  final DateTime doctorADate;
  final String doctorBName;
  final String doctorBSpec;
  final String doctorBHospital;
  final DateTime doctorBDate;
  final List<DiffPoint> points;
  final List<String> whyDiffer;
  final List<String> questions;
  final bool autoGenerated;
  final bool ai;
  const OpinionCase({
    required this.id,
    required this.memberId,
    required this.condition,
    this.recordA,
    this.recordB,
    required this.doctorAName,
    required this.doctorASpec,
    required this.doctorAHospital,
    required this.doctorADate,
    required this.doctorBName,
    required this.doctorBSpec,
    required this.doctorBHospital,
    required this.doctorBDate,
    required this.points,
    required this.whyDiffer,
    required this.questions,
    this.autoGenerated = false,
    this.ai = false,
  });
}

class Medicine {
  final String id;
  final String memberId;
  final String name;
  final String generic;
  final String drugClass;
  final String dose;
  final List<String> times; // "08:00" or "SOS"
  final String prescribedBy;
  final String purpose;
  final String food;
  final int daysLeft;
  const Medicine({
    required this.id,
    required this.memberId,
    required this.name,
    required this.generic,
    this.drugClass = '',
    required this.dose,
    required this.times,
    required this.prescribedBy,
    required this.purpose,
    required this.food,
    required this.daysLeft,
  });
}

class TrendPoint {
  final DateTime date;
  final double value;
  final String lab;
  const TrendPoint(this.date, this.value, this.lab);
}

class Trend {
  final String memberId;
  final String name;
  final String unit;
  final double low;
  final double high;
  final List<TrendPoint> points;
  final String insight;
  const Trend({
    required this.memberId,
    required this.name,
    required this.unit,
    required this.low,
    required this.high,
    required this.points,
    required this.insight,
  });
}

class Appointment {
  final String id;
  final String memberId;
  final String doctor;
  final String speciality;
  final String place;
  final DateTime when;
  final String purpose;
  final String? caseId; // linked opinion case → questions to take along
  const Appointment({
    required this.id,
    required this.memberId,
    required this.doctor,
    required this.speciality,
    required this.place,
    required this.when,
    required this.purpose,
    this.caseId,
  });
}

class TimelineEvent {
  final DateTime date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? recordId;
  final String kind;
  const TimelineEvent(this.date, this.title, this.subtitle, this.icon,
      this.color,
      {this.recordId, this.kind = 'record'});
}

enum AlertKind { critical, duplicateTest, trend, drugOverlap, refill, visit }

class HealthAlert {
  final String id;
  final String memberId;
  final AlertKind kind;
  final String title;
  final String body;
  final String cta;
  final String? recordId;
  const HealthAlert({
    required this.id,
    required this.memberId,
    required this.kind,
    required this.title,
    required this.body,
    required this.cta,
    this.recordId,
  });
}

class AshaPerson {
  final String id;
  final String name;
  final String village;
  final int age;
  final String gender;
  final String phone;
  final String status;
  final int level; // 0 ok, 1 follow-up, 2 urgent
  final List<String> notes;
  final bool pregnant;
  const AshaPerson({
    required this.id,
    required this.name,
    required this.village,
    required this.age,
    required this.gender,
    this.phone = '',
    required this.status,
    required this.level,
    this.notes = const [],
    this.pregnant = false,
  });

  AshaPerson withNote(String n, {String? status, int? level}) => AshaPerson(
        id: id,
        name: name,
        village: village,
        age: age,
        gender: gender,
        phone: phone,
        status: status ?? this.status,
        level: level ?? this.level,
        notes: [n, ...notes],
        pregnant: pregnant,
      );
}
