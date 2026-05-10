import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';

class CurrentSetDraftController {
  SetLogInput? _setLogInput;
  String? _setDraftKey;

  SetLogInput currentInput(ExerciseSetPlanContext planContext) {
    syncToContext(planContext);
    return _setLogInput ?? planContext.defaultSetLogInput;
  }

  SetLogInput inputForLogging(ExerciseSetPlanContext planContext) {
    if (!planContext.showsCurrentSetEditor) {
      return planContext.defaultSetLogInput;
    }
    return currentInput(planContext);
  }

  void syncToContext(ExerciseSetPlanContext planContext) {
    if (_setDraftKey == planContext.setDraftKey) return;
    _setDraftKey = planContext.setDraftKey;
    _setLogInput = planContext.defaultSetLogInput;
  }

  void update(SetLogInput setLogInput) {
    _setLogInput = setLogInput;
  }
}
