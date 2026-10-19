library;

/// Returns current UTC datetime
typedef Clock = DateTime Function();

/// Default implementation reads system time
DateTime systemClock() => DateTime.now().toUtc();
