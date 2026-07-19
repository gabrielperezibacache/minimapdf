export interface TabItem { label: string; value: string; }
export interface TabsProps {
  items: TabItem[];
  value: string;
  onChange?: (value: string) => void;
}
