const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

String fmtDuration(int sec) => sec < 60 ? '$sec s' : '${(sec / 60).round()} min';

String fmtTotal(int min) => min < 60 ? '$min min' : '${min ~/ 60}h ${min % 60}m';