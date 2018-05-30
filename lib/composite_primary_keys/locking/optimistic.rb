module ActiveRecord
  module Locking
    module Optimistic

      private

      silence_warnings do
        def _update_row(attribute_names, attempted_action = "update")
          return super unless locking_enabled?

          begin
            locking_column = self.class.locking_column
            previous_lock_value = read_attribute_before_type_cast(locking_column)
            attribute_names << locking_column

            self[locking_column] += 1

            if composite?
              affected_rows = self.class.unscoped._update_record(
                  arel_attributes_with_values(attribute_names),
                  Hash[self.class.primary_key.zip(id_in_database)].merge(
                      locking_column => previous_lock_value
                  )
              )
            else
              affected_rows = self.class.unscoped._update_record(
                  arel_attributes_with_values(attribute_names),
                  self.class.primary_key => id_in_database,
                  locking_column         => previous_lock_value
              )
            end

            if affected_rows != 1
              raise ActiveRecord::StaleObjectError.new(self, attempted_action)
            end

            affected_rows

              # If something went wrong, revert the locking_column value.
          rescue Exception
            self[locking_column] = previous_lock_value.to_i
            raise
          end
        end
      end
    end
  end
end
