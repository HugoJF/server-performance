#include <sourcemod>
#include <sv-var>

#define PLUGIN_VERSION "1.0"
#define FRAMETIME_HISTORY_SIZE 1000
#define TICKRATE 128

float g_fFrametimeHistory[FRAMETIME_HISTORY_SIZE];
float g_fOrderedHistory[FRAMETIME_HISTORY_SIZE];
int g_iFrametimeHistoryIndex = 0;

public Plugin myinfo = 
{
    name = "Server performance tracker",
    author = "de_nerd",
    description = "",
    version = PLUGIN_VERSION,
    url = "denerdtv.com"
}

public void OnPluginStart()
{
    RegServerCmd("sm_sp_summary", Command_Summary, "Fakes a report");
}

public void OnGameFrame()
{
    float fFrametime = GetFrameComputationTime() * 1000.0;

    g_iFrametimeHistoryIndex = ++g_iFrametimeHistoryIndex % FRAMETIME_HISTORY_SIZE;
    g_fFrametimeHistory[g_iFrametimeHistoryIndex] = fFrametime;
}

float ToFps(float frametime) {
    float fps = 1000 / frametime;

    if (fps > TICKRATE) {
        return float(TICKRATE);
    } else {
        return fps;
    }
}

public Action Command_Summary(int args)
{
    int iterations = -1;
    float sum = 0.0;

    int segments[] = {1, 5, 15, 30, 60};
    float percentiles[] = {0.001, 0.01, 0.1, 0.5};

    float[] accs = new float[sizeof(segments)];
    int[] overs = new int[sizeof(segments)];
    int[] counts = new int[sizeof(segments)];

    float min = 9999.0;
    float max = 0.0;

    while (++iterations < FRAMETIME_HISTORY_SIZE) {
        int index = g_iFrametimeHistoryIndex - iterations;
       
        if (index < 0) {
            index += FRAMETIME_HISTORY_SIZE;
        }

        float value = g_fFrametimeHistory[index];

        g_fOrderedHistory[index] = value;

        if (value == 0.0) {
            continue;
        }

        sum += value;

        if (value < min) {
            min = value;
        }

        if (value > max) {
            max = value;
        }

        for (int i = 0; i < sizeof(segments); i++) {
            bool over = value > 1000 / TICKRATE;

            if (iterations < TICKRATE * segments[i]) {
                accs[i] += value;
                overs[i] += over ? 1 : 0;
                counts[i]++;
            }
        }
    }

    PrintToServer("Min: %f", min);
    PrintToServer("Max: %f", max);

    SortFloats(g_fOrderedHistory, FRAMETIME_HISTORY_SIZE, Sort_Descending);

    for (int i = 0; i < sizeof(percentiles); i++) {
        float percentile = percentiles[i];
        int index = RoundToCeil(float(FRAMETIME_HISTORY_SIZE) * percentile);

        float value = g_fOrderedHistory[index];
        float fps = ToFps(value);

        PrintToServer("%f%% percentile = %f (%f FPS)", percentile, value, fps);
    }

    for (int i = 0; i < sizeof(segments); i++) {
        int ticks = segments[i] * TICKRATE;
        float relative_over = float(overs[i]) / float(ticks);
        float average = accs[i] / float(ticks);

        PrintToServer("=== %d second window ===", segments[i]);
        PrintToServer("   - Average: %f (%f FPS)", average, ToFps(average));
        PrintToServer("   - Over: %d frames (%f%% out of %d)", overs[i], relative_over, counts[i]);
        PrintToServer("=== End of window ===");
        PrintToServer("");
    }

    return Plugin_Handled;
}