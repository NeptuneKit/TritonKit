import { Button, Segmented } from "antd";
import { Settings2 } from "lucide-react";
import { displayLanguageOptions, type DisplayLanguage } from "./inspectorWorkspaceModel";

export function SettingsPage({
  language,
  onBack,
  onLanguageChange,
}: {
  language: DisplayLanguage;
  onBack: () => void;
  onLanguageChange: (language: DisplayLanguage) => void;
}) {
  const isChinese = language === "zh-CN";

  return (
    <main className="settings-page-shell">
      <section className="settings-page" aria-label={isChinese ? "设置" : "Settings"}>
        <div className="settings-page-topbar">
          <Button
            type="link"
            onClick={onBack}
          >
            ← {isChinese ? "返回 Inspect Session" : "Back to Inspect Session"}
          </Button>
          <span>{isChinese ? "Web 本地偏好" : "Local Web preferences"}</span>
        </div>

        <div className="settings-heading">
          <Settings2 size={22} />
          <div>
            <strong>{isChinese ? "设置" : "Settings"}</strong>
            <span>{isChinese ? "独立页面，仅影响本机 Web 展示偏好" : "Dedicated page for local Web display preferences only"}</span>
          </div>
        </div>

        <div className="settings-group">
          <div className="settings-copy">
            <strong>{isChinese ? "语言偏好" : "Language preference"}</strong>
            <span>
              {isChinese
                ? "用于工具区标签、日志和展示层格式化；不改变 CLI / HTTP 机器可读契约。"
                : "Used for tool labels, logs, and display formatting. CLI / HTTP contracts remain unchanged."}
            </span>
          </div>

          {displayLanguageOptions.map((option) => (
            <input
              key={option.id}
              hidden
              type="radio"
              name="display-language"
              value={option.id}
              checked={language === option.id}
              onChange={() => onLanguageChange(option.id)}
            />
          ))}
          <Segmented
            options={displayLanguageOptions.map((option) => ({
              label: (
                <div>
                  <strong>{option.label}</strong>
                  <div style={{ fontSize: 12, color: '#8C8C8C' }}>{option.detail}</div>
                </div>
              ),
              value: option.id,
            }))}
            value={language}
            onChange={(value) => onLanguageChange(value as DisplayLanguage)}
          />
        </div>

        <p className="settings-footnote">
          {isChinese
            ? "偏好保存在当前浏览器的 localStorage，刷新页面后继续生效。"
            : "The preference is stored in this browser's localStorage and survives refreshes."}
        </p>
      </section>
    </main>
  );
}
