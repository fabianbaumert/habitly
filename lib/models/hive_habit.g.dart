// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveHabitAdapter extends TypeAdapter<HiveHabit> {
  @override
  final int typeId = 0;

  @override
  HiveHabit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveHabit(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      createdAt: fields[5] as DateTime,
      userId: fields[6] as String,
      frequencyTypeIndex: fields[7] as int,
      specificDays: (fields[8] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveHabit obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.userId)
      ..writeByte(7)
      ..write(obj.frequencyTypeIndex)
      ..writeByte(8)
      ..write(obj.specificDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveHabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
